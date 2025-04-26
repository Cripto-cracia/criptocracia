use clap::Parser;

#[derive(Parser, Debug)]
#[command(
    name = "criptocracia-voter",
    about = "A simple CLI to vote in a criptocracia election",
    author,
    arg_required_else_help = true,
    help_template = "\
{before-help}{name} 🗳️
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣀⣤⣤⣤⣤⣤⡀⢰⣾⣿⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠴⠾⣿⢿⣿⣿⣿⣿⣿⣷⠘⠿⠿⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣿⣿⣿⣶⡶⢀⣼⣿⠏⠉⠉⠉⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣸⣿⣿⣿⡏⢠⣾⠟⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⢀⣀⣀⣀⣀⣀⡀⢀⣿⣿⣿⣿⣷⣤⡄⠀⣀⣀⣀⣀⣀⡀⠀⠀⠀⠀
⠀⠀⠀⣰⣿⣿⣿⣿⣿⣏⣁⣈⣉⣉⣉⣉⣉⣉⣁⣈⣹⣿⣿⣿⣿⣿⣆⠀⠀⠀
⠀⠀⢀⣉⣉⣉⣉⣉⣉⣉⣉⣉⣉⣉⣉⣉⣉⣉⣉⣉⣉⣉⣉⣉⣉⣉⣉⡀⠀⠀
⠀⠀⢸⡏⣉⣉⣉⣉⣉⣉⣉⣉⣉⣉⣉⣉⣉⣉⣉⣉⣉⣉⣉⣉⣉⣉⢹⡇⠀⠀
⠀⠀⢸⡇⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⢸⡇⠀⠀
⠀⠀⢸⡇⣿⡟⢀⣈⠙⠻⠿⠟⢉⣤⣆⠘⢿⣿⣿⣿⠋⣀⠙⠻⣿⣿⢸⡇⠀⠀
⠀⠀⢸⡇⠟⢀⣾⣿⠟⠂⣠⣾⣿⣿⣿⣧⡈⢉⡉⢀⣴⣿⣿⣦⣈⠙⢸⡇⠀⠀
⠀⠀⢸⡇⢀⣾⣿⣷⡄⠹⣿⣿⣿⣿⣿⣿⡷⠀⣠⣾⣿⣿⣿⣿⣿⣷⢸⡇⠀⠀
⠀⠀⢸⣇⣈⣉⣉⣉⣉⣀⣉⣉⣉⣉⣉⣉⣁⣈⣉⣉⣉⣉⣉⣉⣉⣉⣸⡇⠀⠀
⠀⠀⠈⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠁⠀⠀

{about-with-newline}
{author-with-newline}
{usage-heading} {usage}

{all-args}{after-help}
",
    version
)]
pub struct CLIArgs {
    #[arg(
        short = 's',
        long = "secret",
        required = true,
        help = "Enter the private key of the voter, the public key derivated from this private key must be registered on the Criptocracia Election Commission."
    )]
    pub secret: String,
    #[arg(
        short = 'e',
        long = "election-id",
        required = true,
        help = "Enter the election Id."
    )]
    pub election_id: String,
    #[arg(
        short = 'c',
        long = "electoral-commission",
        required = true,
        help = "Enter the electoral commission pubkey."
    )]
    pub electoral_commission_pubkey: String,
    #[arg(
        short = 'v',
        long = "vote",
        required = false,
        help = "Enter the Id of the candidate you want to vote for.",
    )]
    pub vote: usize,
    #[arg(
        short = 't',
        long = "request-token",
        required = false,
        help = "Request a voting token for a hash of a nonce.",
    )]
    pub voting_token: bool,
}