pub mod election;
pub mod settings;
pub mod util;

use crate::election::{Election, Message, Status};
use crate::settings::{Settings, init_settings};
use crate::util::setup_logger;

use base64::engine::{Engine, general_purpose};
use chrono::{Duration as ChronoDuration, Utc};
use crossterm::event::{Event as CEvent, EventStream, KeyCode, KeyEvent};
use crossterm::execute;
use crossterm::terminal::{
    EnterAlternateScreen, LeaveAlternateScreen, disable_raw_mode, enable_raw_mode,
};
use futures::StreamExt;
use nostr_sdk::prelude::RelayPoolNotification;
use nostr_sdk::prelude::*;
use num_bigint_dig::{BigUint, RandBigInt};
use rand::rngs::OsRng;
use ratatui::Terminal;
use ratatui::backend::CrosstermBackend;
use ratatui::layout::{Constraint, Direction, Layout};
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, Borders, Cell, Paragraph, Row, Table, Tabs};
use sha2::{Digest, Sha256};
use std::cmp::Reverse;
use std::io::stdout;
use std::str::FromStr;
use std::sync::OnceLock;
use std::sync::{Arc, Mutex};
use tokio::time::{Duration, interval};

/// Constructs (or copies) the configuration file and loads it.
static SETTINGS: OnceLock<Settings> = OnceLock::new();

// Official Mostro colors.
const PRIMARY_COLOR: Color = Color::Rgb(3, 255, 254); // #03fffe
const BACKGROUND_COLOR: Color = Color::Rgb(5, 35, 39); // #052327

/// Draws the TUI interface with tabs and active content.
/// The "Elections" tab shows a table of active elections and highlights the selected row.
fn ui_draw(
    f: &mut ratatui::Frame,
    active_area: usize,
    elections: &Arc<Mutex<Vec<Election>>>,
    selected_election_idx: usize,
    selected_candidate_idx: usize,
) {
    let chunks = Layout::new(
        Direction::Vertical,
        [30, 40, 30].map(Constraint::Percentage),
    )
    .split(f.area());

    // === AREA 0: Elections ===
    let header = Row::new(
        ["Id", "Name", "Status", "Starts"]
            .iter()
            .map(|h| Cell::from(*h))
            .collect::<Vec<_>>(),
    )
    .style(Style::default().add_modifier(Modifier::BOLD));

    let elections_lock = elections.lock().unwrap();
    let mut rows = Vec::with_capacity(elections_lock.len());
    for (i, e) in elections_lock.iter().enumerate() {
        let mut row = Row::new(vec![
            Cell::from(e.id.to_string()),
            Cell::from(e.name.clone()),
            Cell::from(match e.status {
                Status::Open => "Open",
                Status::InProgress => "In Progress",
                Status::Finished => "Finished",
                Status::Canceled => "Canceled",
            }),
            Cell::from(
                chrono::DateTime::from_timestamp(e.start_time as i64, 0)
                    .map(|dt| dt.format("%Y-%m-%d %H:%M").to_string())
                    .unwrap_or_else(|| "Invalid".into()),
            ),
        ]);
        if active_area == 0 && i == selected_election_idx {
            row = row.style(Style::default().bg(PRIMARY_COLOR).fg(Color::Black));
        }
        rows.push(row);
    }

    let mut block_e = Block::default()
        .title("Elections")
        .borders(Borders::ALL)
        .border_type(ratatui::widgets::BorderType::Rounded)
        .style(Style::default().bg(BACKGROUND_COLOR));
    if active_area == 0 {
        block_e = block_e
            .title_style(Style::default().bg(PRIMARY_COLOR).fg(Color::Black))
            .border_style(Style::default().bg(PRIMARY_COLOR).fg(Color::Black));
    }

    let table_e = Table::new(
        rows,
        &[
            Constraint::Length(5),
            Constraint::Min(10),
            Constraint::Length(12),
            Constraint::Length(18),
        ],
    )
    .header(header)
    .block(block_e);
    f.render_widget(table_e, chunks[0]);

    // === AREA 1: Candidates ===
    // If a valid election is selected, display its candidates:
    let mut cand_rows = Vec::new();
    if let Some(e) = elections_lock.get(selected_election_idx) {
        for (i, c) in e.candidates.iter().enumerate() {
            let mut row = Row::new(vec![
                Cell::from(c.id.to_string()),
                Cell::from(c.name.clone()),
            ]);
            if active_area == 1 && i == selected_candidate_idx {
                row = row.style(Style::default().bg(PRIMARY_COLOR).fg(Color::Black));
            }
            cand_rows.push(row);
        }
    }

    let mut block_c = Block::default()
        .title("Candidates")
        .borders(Borders::ALL)
        .border_type(ratatui::widgets::BorderType::Rounded)
        .style(Style::default().bg(BACKGROUND_COLOR));
    if active_area == 1 {
        block_c = block_c
            .title_style(Style::default().bg(PRIMARY_COLOR).fg(Color::Black))
            .border_style(Style::default().bg(PRIMARY_COLOR).fg(Color::Black));
    }

    let table_c = Table::new(cand_rows, &[Constraint::Length(5), Constraint::Min(10)])
        .header(
            Row::new(
                ["Id", "Name"]
                    .iter()
                    .map(|h| Cell::from(*h))
                    .collect::<Vec<_>>(),
            )
            .style(Style::default().add_modifier(Modifier::BOLD)),
        )
        .block(block_c);
    f.render_widget(table_c, chunks[1]);

    // === AREA 2: Ballot ===
    let mut block_b = Block::default()
        .title("Ballot")
        .borders(Borders::ALL)
        .border_type(ratatui::widgets::BorderType::Rounded)
        .style(Style::default().bg(BACKGROUND_COLOR));
    if active_area == 2 {
        block_b = block_b
            .title_style(Style::default().bg(PRIMARY_COLOR).fg(Color::Black))
            .border_style(Style::default().bg(PRIMARY_COLOR).fg(Color::Black));
    }
    f.render_widget(block_b, chunks[2]);
}

// async fn obtain_token(client: Client) -> BigUint {

// }

#[tokio::main]
async fn main() -> Result<(), anyhow::Error> {
    log::info!("Criptocracia started");
    let settings = init_settings();
    // db::init_db().await?;
    // Initialize logger
    setup_logger(&settings.log_level).expect("Can't initialize logger");
    // Set the terminal in raw mode and switch to the alternate screen.
    enable_raw_mode()?;
    let mut stdout = stdout();
    execute!(stdout, EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    // Shared state: elections are stored in memory.
    let elections: Arc<Mutex<Vec<Election>>> = Arc::new(Mutex::new(Vec::new()));
    let mut active_area = 0; // 0 = Elections, 1 = Candidates, 2 = Ballot
    let mut selected_election_idx = 0;
    let mut selected_candidate_idx = 0;

    // Configure Nostr client.
    let my_keys = Keys::parse(&settings.secret_key)?;
    let client = Client::new(my_keys.clone());
    // Add the Mostro relay.
    client.add_relay("wss://relay.mostro.network").await?;
    client.connect().await;

    // EC Pubkey.
    let ec_pubkey = PublicKey::from_str(settings.ec_public_key.as_str())
        .map_err(|e| anyhow::anyhow!("Invalid EC pubkey: {}", e))?;

    // Calculate timestamp for events in the last day.
    let since_time = Utc::now()
        .checked_sub_signed(ChronoDuration::days(1))
        .ok_or_else(|| anyhow::anyhow!("Failed to compute time"))?
        .timestamp() as u64;
    let timestamp = Timestamp::from(since_time);

    // Build the filter for NIP-69 (orders) events from Mostro.
    let filter = Filter::new().author(ec_pubkey).limit(20).since(timestamp);

    // Subscribe to the filter.
    client.subscribe(filter, None).await?;

    // Build the filter for NIP-59 events from the Electoral commission.
    let filter = Filter::new()
        .kind(Kind::GiftWrap)
        .pubkey(my_keys.public_key())
        .limit(20)
        .since(timestamp);
    client.subscribe(filter, None).await?;

    let cloned_client = client.clone();

    // Asynchronous task to handle incoming notifications.
    let elections_clone = Arc::clone(&elections);
    tokio::spawn(async move {
        let mut notifications = client.notifications();
        while let Ok(n) = notifications.recv().await {
            if let RelayPoolNotification::Event { event, .. } = n {
                if let Kind::GiftWrap = event.kind {
                    // Validate event signature
                    if event.verify().is_err() {
                        log::warn!("Invalid event signature: {}", event.id);
                        continue;
                    }
                    let event = match nip59::extract_rumor(&my_keys, &event).await {
                        Ok(u) => u,
                        Err(_) => {
                            log::warn!("Error unwrapping gift");
                            continue;
                        }
                    };
                    log::info!("Received event: {:#?}", event);
                    let message = Message::from_json(&event.rumor.content).unwrap();
                    match message.kind {
                        1 => log::info!("Token request response {}", message.content),
                        2 => log::info!("Voter response {}", message.content),
                        _ => log::warn!("Unknown response {}", message.content),
                    }

                    continue;
                } else if let Ok(e) = Election::parse_event(&event) {
                    let mut lock = elections_clone.lock().unwrap();
                    if !lock.iter().any(|x| x.id == e.id) {
                        lock.push(e);
                        lock.sort_by_key(|e| Reverse(e.start_time));
                    }
                } else {
                    continue;
                }
            }
        }
    });

    // Event handling: keyboard input and periodic UI refresh.
    let mut events = EventStream::new();
    let mut refresh_interval = interval(Duration::from_millis(200));

    loop {
        tokio::select! {
            maybe_event = events.next() => {
                if let Some(Ok(CEvent::Key(KeyEvent { code, .. }))) = maybe_event {
                    match code {
                        KeyCode::Char('q') | KeyCode::Esc => break,
                        KeyCode::Up => {
                            if active_area == 0 {
                                if selected_election_idx > 0 { selected_election_idx -= 1; }
                            } else if active_area == 1 {
                                if selected_candidate_idx > 0 { selected_candidate_idx -= 1; }
                            }
                        }
                        KeyCode::Down => {
                            if active_area == 0 {
                                let len = elections.lock().unwrap().len();
                                if selected_election_idx + 1 < len {
                                    selected_election_idx += 1;
                                }
                            } else if active_area == 1 {
                                if let Some(e) = elections.lock().unwrap().get(selected_election_idx) {
                                    if selected_candidate_idx + 1 < e.candidates.len() {
                                        selected_candidate_idx += 1;
                                    }
                                }
                            }
                        }
                        KeyCode::Enter => {
                            if active_area == 0 {
                                // Obtain token for the selected election.
                                // Create random nonce and hash it.
                                let nonce: BigUint = OsRng.gen_biguint(128);
                                let h_n_bytes = Sha256::digest(nonce.to_bytes_be());
                                // Coding to Base64.
                                let h_n_b64 = general_purpose::STANDARD.encode(&h_n_bytes);
                                let election_id = {
                                    let elections_lock = elections.lock().unwrap();
                                    elections_lock.get(selected_election_idx).map(|e| e.id.clone())
                                };

                                if let Some(election_id) = election_id {
                                    let message = Message::new(
                                        election_id,
                                        1,
                                        h_n_b64.clone(),
                                    );
                                    let message_json = serde_json::to_string(&message)?;
                                    log::info!("Token request content: {}", message_json);
                                    let my_keys = Keys::parse(&settings.secret_key)?;
                                    // Creates a "rumor" with the hash of the nonce.
                                    let rumor: UnsignedEvent = EventBuilder::text_note(message_json).build(my_keys.public_key());

                                    // Wraps the rumor in a Gift Wrap.
                                    let gift_wrap: Event = EventBuilder::gift_wrap(&my_keys, &ec_pubkey, rumor, None).await?;

                                    // Send the Gift Wrap
                                    cloned_client.send_event(&gift_wrap).await?;

                                    log::info!("Token request sent!");
                                    // Wait for the Gift Wrap to be unwrapped.
                                }

                                active_area = 1;
                                selected_candidate_idx = 0;
                            } else if active_area == 1 {
                                // Log the selected candidate details
                                let selected_candidate = {
                                    let elections_lock = elections.lock().unwrap();
                                    elections_lock.get(selected_election_idx).map(|e| {
                                        let candidate = e.candidates[selected_candidate_idx].clone();
                                        let election_id = e.id.clone();
                                        (candidate, election_id)
                                    })
                                };

                                if let Some((c, election_id)) = selected_candidate {
                                    log::info!("Selected candidate: {:#?}", c);
                                    let message = Message::new(
                                        election_id,
                                        2,
                                        c.id.to_string(),
                                    );
                                    // TODO: the vote should be sent with the token
                                    let message_json = serde_json::to_string(&message)?;
                                    log::info!("Vote to be sent: {}", message_json);
                                    // We generate a random key to keep the vote secret
                                    let my_keys = Keys::generate();
                                    // Creates a "rumor" with the hash of the nonce.
                                    let rumor: UnsignedEvent = EventBuilder::text_note(message_json).build(my_keys.public_key());

                                    // Wraps the rumor in a Gift Wrap.
                                    let gift_wrap: Event = EventBuilder::gift_wrap(&my_keys, &ec_pubkey, rumor, None).await?;

                                    // Send the Gift Wrap
                                    cloned_client.send_event(&gift_wrap).await?;

                                    log::info!("Vote sent!");
                                    // Wait for the Gift Wrap to be unwrapped.
                                }
                                // TODO: handle candidate confirmation or switch to Ballot area
                            }
                        }
                        _ => {}
                    }
                }
            },
            _ = refresh_interval.tick() => {
                // Refresh the UI even if there is no input.
            }
        }

        terminal.draw(|f| {
            ui_draw(
                f,
                active_area,
                &elections,
                selected_election_idx,
                selected_candidate_idx,
            )
        })?;
    }

    // Restore terminal to its original state.
    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    terminal.show_cursor()?;

    Ok(())
}
