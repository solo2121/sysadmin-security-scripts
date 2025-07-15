// rhino-update – colourful one-shot update & cleanup for Rhino Linux
// Requires sudo.

use std::env;
use std::io::{self, Write};
use std::process::{Command, Stdio};

// ANSI helpers ----------------------------------------------------------------
const RESET: &str = "\x1b[0m";
const BOLD: &str = "\x1b[1m";
const RED: &str = "\x1b[31m";
const GREEN: &str = "\x1b[32m";
const YELLOW: &str = "\x1b[33m";
const BLUE: &str = "\x1b[34m";
const MAGENTA: &str = "\x1b[35m";
const CYAN: &str = "\x1b[36m";

macro_rules! color_print {
    ($color:expr, $($arg:tt)*) => {{
        print!("{}{}", $color, format_args!($($arg)*));
        print!("{}", RESET);
    }};
}

// Run a command, streaming its output, and exit on failure --------------------
fn run(cmd: &[&str], description: &str) -> io::Result<()> {
    if !description.is_empty() {
        color_print!(format!("{BLUE}{BOLD}➜ {RESET}{}"), description);
        println!();
    }
    color_print!("{}▶ ", CYAN);
    println!("{}", cmd.join(" "));

    let mut iter = cmd.iter();
    let program = iter.next().unwrap_or(&"");
    let status = Command::new(program)
        .args(iter)
        .stdin(Stdio::null())
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .status()?;

    if !status.success() {
        color_print!("{RED}❌ Command failed with exit code: {:?}\n", status.code());
        std::process::exit(status.code().unwrap_or(1));
    }
    Ok(())
}

fn main() {
    if env::uid() != 0 {
        color_print!("{RED}❌ This script must be run as root (sudo).\n");
        std::process::exit(1);
    }

    color_print!(
        "{MAGENTA}{BOLD}🦏 Rhino Linux Update & Cleanup{}\n\n",
        RESET
    );

    let result = || -> io::Result<()> {
        run(&["rpk", "update", "-y"], "Updating all packages …")?;
        run(&["rpk", "cleanup", "-y"], "Purging orphaned packages …")?;
        Ok(())
    }();

    if let Err(e) = result {
        color_print!("{RED}❌ Error: {}\n", e);
        std::process::exit(1);
    }

    color_print!("{GREEN}✅ Rhino Linux is up-to-date and squeaky-clean!\n");
}