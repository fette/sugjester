# Sugjester OmniFocus Export Setup Guide

This guide will help you set up automatic export of your book consideration lists from OmniFocus to the Sugjester system.

## Prerequisites

- OmniFocus 4 for Mac
- Your book lists organized in the specific OmniFocus projects 
- macOS with Terminal access

## Step 1: Verify Your OmniFocus Projects

The export script is configured to work with these specific OmniFocus projects:

- **Books to consider** (`omnifocus:///project/aCuCB0X3CYn`)
- **Books owned to read** (`omnifocus:///project/gipgWMqDMdb`)  
- **Japanese books to consider** (`omnifocus:///project/bPvbY14zt9G`)

The script will:
- Combine "Books to consider" and "Books owned to read" into a single English export
- Export "Japanese books to consider" separately
- Only export incomplete tasks (completed books are ignored)

**Pro Tip:** You can use ⭐️ or `@high-priority` in task names to mark high-priority books.

## Step 2: Install the OmniFocus Plugin

1. **Copy the plugin file:**
   ```bash
   cp omnifocus-export.omnifocusjs ~/Library/Application\ Scripts/com.omnigroup.OmniFocus4/Plug-Ins/
   ```

   If the directory doesn't exist, create it:
   ```bash
   mkdir -p ~/Library/Application\ Scripts/com.omnigroup.OmniFocus4/Plug-Ins/
   ```

2. **Restart OmniFocus** to load the new plugin

3. **Verify installation:**
   - Open OmniFocus
   - Go to **Automation** menu
   - You should see "Export Books for Sugjester" in the list

## Step 3: Test Manual Export

1. In OmniFocus, go to **Automation → Export Books for Sugjester**
2. The script will create JSON files in the `data/` directory
3. Check that the following files were created:
   - `data/english-books-to-consider.json`
   - `data/japanese-books-to-consider.json`
   - `data/export-summary.json`

## Step 4: Set Up Automated Scheduling (Optional)

To run the export automatically every day at 9 AM:

1. **Create a launchd service:**
   ```bash
   # Copy the provided plist file to the LaunchAgents directory
   cp com.sugjester.omnifocus-export.plist ~/Library/LaunchAgents/
   
   # Update the path in the plist to match your actual project location
   sed -i '' "s|/Users/fet/source/sugjester|$(pwd)|g" ~/Library/LaunchAgents/com.sugjester.omnifocus-export.plist
   ```

2. **Load the service:**
   ```bash
   launchctl load ~/Library/LaunchAgents/com.sugjester.omnifocus-export.plist
   ```

3. **Start the service:**
   ```bash
   launchctl start com.sugjester.omnifocus-export
   ```

## Step 5: Verify Automation

- Check the log file: `data/export.log`
- The automation will run daily and commit changes to git if this is a git repository
- You can manually trigger the automation with: `./automate-export.sh`

## Troubleshooting

### Plugin Not Appearing
- Ensure the file is in the correct directory with `.omnifocusjs` extension
- Restart OmniFocus completely
- Check that the file isn't quarantined: `xattr -d com.apple.quarantine omnifocus-export.omnifocusjs`

### No Books Exported
- Verify the project IDs are correct and projects exist in your OmniFocus
- Check that tasks are not completed (completed tasks are excluded)
- Look at the export summary for details
- Ensure the projects contain actual tasks, not just empty projects

### Automation Not Running
- Check if the launchd service is loaded: `launchctl list | grep sugjester`
- View service logs: `tail -f ~/Library/Logs/com.sugjester.omnifocus-export.log`
- Ensure OmniFocus has necessary permissions

## Customization

### Changing Export Schedule
Edit the `com.sugjester.omnifocus-export.plist` file and modify the `StartCalendarInterval` section:

```xml
<key>StartCalendarInterval</key>
<dict>
    <key>Hour</key>
    <integer>9</integer>  <!-- Change this hour -->
    <key>Minute</key>
    <integer>0</integer>  <!-- And/or this minute -->
</dict>
```

### Changing Project IDs
If your project IDs are different, edit the `omnifocus-export.omnifocusjs` file and update the `projectIds` object with your actual project IDs. You can find project IDs by right-clicking a project in OmniFocus and selecting "Copy as Link".

### Changing Output Format
The JSON structure can be customized in the export script to match your specific needs.

## File Structure

After setup, your project will have:
```
sugjester/
├── data/
│   ├── english-books-to-consider.json
│   ├── japanese-books-to-consider.json
│   ├── export-summary.json
│   └── export.log
├── omnifocus-export.omnifocusjs
├── automate-export.sh
└── setup-automation.md (this file)
```

## Integration with Sugjester

The exported JSON files follow the format expected by the Sugjester system as specified in `instructions.md`. The files will be automatically processed when the AI system needs to make recommendations.
