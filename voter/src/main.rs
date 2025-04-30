pub mod settings;
pub mod util;
pub mod election;

use crate::settings::{Settings, init_settings};
use crate::util::setup_logger;
use crate::election::{Election, Status};

use std::str::FromStr;
use std::sync::{Arc, Mutex};
use std::io::stdout;
use chrono::{Utc, Duration as ChronoDuration};
use futures::StreamExt;
use crossterm::event::{Event as CEvent, EventStream, KeyCode, KeyEvent};
use crossterm::terminal::{enable_raw_mode, disable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen};
use crossterm::execute;
use ratatui::backend::CrosstermBackend;
use ratatui::layout::{Constraint, Direction, Layout};
use ratatui::style::{Style, Modifier, Color};
use ratatui::widgets::{Tabs, Block, Borders, Table, Row, Cell, Paragraph};
use ratatui::text::{Line, Span};
use ratatui::Terminal;
use tokio::time::{interval, Duration};
use nostr_sdk::prelude::*;
use nostr_sdk::prelude::RelayPoolNotification;
use std::sync::OnceLock;

/// Constructs (or copies) the configuration file and loads it.
static SETTINGS: OnceLock<Settings> = OnceLock::new();

// Official Mostro colors.
const PRIMARY_COLOR: Color = Color::Rgb(3, 255, 254);    // #03fffe
const BACKGROUND_COLOR: Color = Color::Rgb(5, 35, 39);   // #052327

/// Draws the TUI interface with tabs and active content.
/// The "Elections" tab shows a table of active elections and highlights the selected row.
fn ui_draw(
    f: &mut ratatui::Frame,
    active_area: usize,
    elections: &Arc<Mutex<Vec<Election>>>,
    selected_order_idx: usize,
) {
    // Create layout: two rows
    let vertical_chunks = Layout::new(
        Direction::Vertical,
        &[Constraint::Percentage(40), Constraint::Percentage(60)]
    )
    .split(f.area());
    let horizontal_chunks = Layout::new(
        Direction::Horizontal,
        &[Constraint::Percentage(50), Constraint::Percentage(50)]
    )
        .split(vertical_chunks[0]);

        let header_cells = ["Id", "Name", "Status", "Starts"]
        .iter()
        .map(|h| Cell::from(*h))
        .collect::<Vec<Cell>>();
    let header = Row::new(header_cells)
        .style(Style::default().add_modifier(Modifier::BOLD));

    let elections_lock = elections.lock().unwrap();
    let rows: Vec<Row> = elections_lock.iter().enumerate().map(|(i, election)| {
        let row = Row::new(vec![
            Cell::from(election.id.to_string()),
            Cell::from(election.name.clone()),
            Cell::from(match election.status {
                Status::Open => "Open",
                Status::InProgress => "In Progress",
                Status::Finished => "Finished",
                Status::Canceled => "Canceled",
            }),
            Cell::from(election.start_time.to_string()),
        ]);
        if i == selected_order_idx {
            // Highlight the selected row.
            row.style(Style::default().bg(PRIMARY_COLOR).fg(Color::Black))
        } else {
            row
        }
    }).collect();

    let elections_table = Table::new(
        rows,
        &[
            Constraint::Length(36),
            Constraint::Length(12),
            Constraint::Max(10),
            Constraint::Max(10),
        ]
    )
    .header(header)
    .block(Block::default().title("Elections").borders(Borders::ALL).style(Style::default().bg(BACKGROUND_COLOR)));
    f.render_widget(elections_table, horizontal_chunks[0]);

    f.render_widget(
        Block::default()
                .title("Candidates")
                .borders(Borders::ALL)
                .style(Style::default().bg(BACKGROUND_COLOR)),
        horizontal_chunks[1]);
    let ballot_area = vertical_chunks[1];


    f.render_widget(        Block::default()
    .title("Ballot")
    .borders(Borders::ALL)
    .style(Style::default().bg(BACKGROUND_COLOR)), ballot_area);
}

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

    // Configure Nostr client.
    let my_keys = Keys::parse(&settings.secret_key)?;
    let client = Client::new(my_keys);
    // Add the Mostro relay.
    client.add_relay("wss://relay.mostro.network").await?;
    client.connect().await;

    // EC Pubkey.
    let ec_pubkey = PublicKey::from_str(settings.ec_public_key.as_str())
        .map_err(|e| anyhow::anyhow!("Invalid EC pubkey: {}", e))?;

    // Calculate timestamp for events in the last 7 days.
    let since_time = Utc::now()
        .checked_sub_signed(ChronoDuration::days(7))
        .ok_or_else(|| anyhow::anyhow!("Failed to compute time"))?
        .timestamp() as u64;
    let timestamp = Timestamp::from(since_time);

    // Build the filter for NIP-69 (orders) events from Mostro.
    let filter = Filter::new()
        .author(ec_pubkey)
        .limit(20)
        .since(timestamp);

    // Subscribe to the filter.
    client.subscribe(filter, None).await?;

    // Asynchronous task to handle incoming notifications.
    let elections_clone = Arc::clone(&elections);
    let mut notifications = client.notifications();
    tokio::spawn(async move {
        while let Ok(notification) = notifications.recv().await {
            if let RelayPoolNotification::Event { event, .. } = notification {
                match Election::parse_event(&event) {
                    Ok(election) => {
                        let mut elections_lock = elections_clone.lock().unwrap();
                        elections_lock.push(election);
                    }
                    Err(err) => {
                        log::error!("Failed to parse election: {}", err);
                    }
                }
            }
        }
    });

    // Event handling: keyboard input and periodic UI refresh.
    let mut events = EventStream::new();
    let mut refresh_interval = interval(Duration::from_millis(500));
    let mut active_area: usize = 0;
    // Selected election index
    let mut selected_election_idx: usize = 0;

    loop {
        tokio::select! {
            maybe_event = events.next() => {
                if let Some(Ok(event)) = maybe_event {
                    if let CEvent::Key(KeyEvent { code, .. }) = event {
                        match code {
                            KeyCode::Left => {
                                if active_area > 0 {
                                    active_area -= 1;
                                }
                            }
                            KeyCode::Right => {
                                if active_area < 3 {
                                    active_area += 1;
                                }
                            }
                            KeyCode::Up => {
                                if active_area == 0 {
                                    let orders_len = elections.lock().unwrap().len();
                                    if orders_len > 0 && selected_election_idx > 0 {
                                        selected_election_idx -= 1;
                                    }
                                }
                            }
                            KeyCode::Down => {
                                if active_area == 0 {
                                    let orders_len = elections.lock().unwrap().len();
                                    if orders_len > 0 && selected_election_idx < orders_len.saturating_sub(1) {
                                        selected_election_idx += 1;
                                    }
                                }
                            }

                            KeyCode::Char('q') | KeyCode::Esc => break,
                            _ => {}
                        }
                    }
                }
            },
            _ = refresh_interval.tick() => {
                // Refresh the UI even if there is no input.
            }
        }

        terminal.draw(|f| ui_draw(f, active_area, &elections, selected_election_idx))?;
    }

    // Restore terminal to its original state.
    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    terminal.show_cursor()?;

    Ok(())
}
