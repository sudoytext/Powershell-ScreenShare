
```markdown
# ScreenSharing Tool

ScreenSharing Tool is a lightweight PowerShell-based script designed to extract and display BAM (Background Activity Moderator) registry entries on Windows machines. The tool also validates file signatures and provides insights into user activity.

## Features

- **BAM Key Parsing**: Retrieves BAM registry entries for logged users.
- **File Signature Validation**: Checks for the validity of executable file signatures.
- **TimeZone Detection**: Displays local and UTC timestamps for last file access.
- **Interactive UI**: Outputs results in a user-friendly grid view.

## Requirements

- Windows Operating System
- PowerShell 5.1 or later
- Administrator privileges

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/ytext/Powershell-ScreenShare.git
   ```
2. Navigate to the script's directory:
   ```bash
   cd screensharing-tool
   ```

## Usage

1. Run the script with Administrator privileges:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\ScreenSharingTool.ps1
   ```
## License
THIS IS A REMAKE 
This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
