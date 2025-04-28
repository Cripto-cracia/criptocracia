pub mod settings;

use crate::settings::{Settings, init_settings};

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
use fern::Dispatch;
use chrono::Local;
use nostr_sdk::prelude::*;
use nostr_sdk::prelude::RelayPoolNotification;
use std::sync::OnceLock;

/// Constructs (or copies) the configuration file and loads it.
static SETTINGS: OnceLock<Settings> = OnceLock::new();

// Official Mostro colors.
const PRIMARY_COLOR: Color = Color::Rgb(3, 255, 254);    // #03fffe
const BACKGROUND_COLOR: Color = Color::Rgb(5, 35, 39);   // #052327

/// Initialize logger function
fn setup_logger(level: &str) -> Result<(), fern::InitError> {
    let log_level = match level.to_lowercase().as_str() {
        "trace" => log::LevelFilter::Trace,
        "debug" => log::LevelFilter::Debug,
        "info" => log::LevelFilter::Info,
        "warn" => log::LevelFilter::Warn,
        "error" => log::LevelFilter::Error,
        _ => log::LevelFilter::Info, // Default to Info for invalid values
    };
    Dispatch::new()
        .format(|out, message, record| {
            out.finish(format_args!(
                "[{}] [{}] - {}",
                Local::now().format("%Y-%m-%d %H:%M:%S"),
                record.level(),
                message
            ))
        })
        .level(log_level)
        .chain(fern::log_file("app.log")?) // Guarda en logs/app.log
        .apply()?;
    Ok(())
}

pub enum Status {
    Active,
    InProgress,
    Finished,
    Canceled,
}
pub struct Candidate {
    pub id: u8,
    pub name: &'static str,
}

impl Candidate {
    pub fn new(id: u8, name: &'static str) -> Self {
        Self { id, name }
    }
}

pub struct Election {
    pub id: String,
    pub candidate: Vec<Candidate>,
    pub start_time: u64,
    pub end_time: u64,
    pub status: Status,
}

/// Draws the TUI interface with tabs and active content.
/// The "Elections" tab shows a table of active elections and highlights the selected row.
fn ui_draw(
    f: &mut ratatui::Frame,
    active_tab: usize,
    elections: &Arc<Mutex<Vec<Election>>>,
    selected_order_idx: usize,
) {
    // Create layout: one row for tabs and the rest for content.
    let chunks = Layout::new(
        Direction::Vertical,
        &[Constraint::Length(3), Constraint::Min(0)]
    )
    .split(f.area());

    // Define tab titles.
    let tab_titles = ["Elections", "My Elections", "Vote", "Info"]
        .iter()
        .map(|t| Line::from(*t))
        .collect::<Vec<Line>>();
    let tabs = Tabs::new(tab_titles)
        .select(active_tab)
        .block(Block::default().borders(Borders::ALL).style(Style::default().bg(BACKGROUND_COLOR)))
        .highlight_style(Style::default().fg(PRIMARY_COLOR).add_modifier(Modifier::BOLD));
    f.render_widget(tabs, chunks[0]);

    let content_area = chunks[1];
    if active_tab == 0 {
        // "Orders" tab: show table with pending orders.
        let header_cells = ["Id", "Status", "Starts", "Ends"]
            .iter()
            .map(|h| Cell::from(*h))
            .collect::<Vec<Cell>>();
        let header = Row::new(header_cells)
            .style(Style::default().add_modifier(Modifier::BOLD));

        let orders_lock = elections.lock().unwrap();
        let rows: Vec<Row> = orders_lock.iter().enumerate().map(|(i, _election)| {
            let row = Row::new(vec![
                Cell::from(""),
                Cell::from(""),
                Cell::from(""),
                Cell::from(""),
            ]);
            if i == selected_order_idx {
                // Highlight the selected row.
                row.style(Style::default().bg(PRIMARY_COLOR).fg(Color::Black))
            } else {
                row
            }
        }).collect();

        let table = Table::new(
            rows,
            &[
                Constraint::Max(5),
                Constraint::Max(11),
                Constraint::Max(5),
                Constraint::Max(12),
                Constraint::Min(10),
            ]
        )
        .header(header)
        .block(Block::default().title("Elections").borders(Borders::ALL).style(Style::default().bg(BACKGROUND_COLOR)));
        f.render_widget(table, content_area);
    } else if active_tab == 1 {
        let paragraph = Paragraph::new(Span::raw("Coming soon"))
            .block(Block::default().title("My elections").borders(Borders::ALL).style(Style::default().bg(BACKGROUND_COLOR)));
        f.render_widget(paragraph, content_area);
    } else if active_tab == 2 {
        let paragraph = Paragraph::new(Span::raw("Coming soon"))
            .block(Block::default().title("Vote").borders(Borders::ALL).style(Style::default().bg(BACKGROUND_COLOR)));
        f.render_widget(paragraph, content_area);
    } else if active_tab == 3 {
        let paragraph = Paragraph::new(Span::raw("Coming soon"))
            .block(Block::default().title("Info").borders(Borders::ALL).style(Style::default().bg(BACKGROUND_COLOR)));
        f.render_widget(paragraph, content_area);
    }
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
                let mut elections_lock = elections_clone.lock().unwrap();
                // TODO
            }
        }
    });

    // Event handling: keyboard input and periodic UI refresh.
    let mut events = EventStream::new();
    let mut refresh_interval = interval(Duration::from_millis(500));
    let mut active_tab: usize = 0;
    // Selected order index for the "Orders" table.
    let mut selected_order_idx: usize = 0;

    loop {
        tokio::select! {
            maybe_event = events.next() => {
                if let Some(Ok(event)) = maybe_event {
                    if let CEvent::Key(KeyEvent { code, .. }) = event {
                        match code {
                            KeyCode::Left => {
                                if active_tab > 0 {
                                    active_tab -= 1;
                                }
                            }
                            KeyCode::Right => {
                                if active_tab < 3 {
                                    active_tab += 1;
                                }
                            }
                            KeyCode::Up => {
                                if active_tab == 0 {
                                    let orders_len = elections.lock().unwrap().len();
                                    if orders_len > 0 && selected_order_idx > 0 {
                                        selected_order_idx -= 1;
                                    }
                                }
                            }
                            KeyCode::Down => {
                                if active_tab == 0 {
                                    let orders_len = elections.lock().unwrap().len();
                                    if orders_len > 0 && selected_order_idx < orders_len.saturating_sub(1) {
                                        selected_order_idx += 1;
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

        terminal.draw(|f| ui_draw(f, active_tab, &elections, selected_order_idx))?;
    }

    // Restore terminal to its original state.
    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    terminal.show_cursor()?;

    Ok(())
}
