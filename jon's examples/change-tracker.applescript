#!/usr/bin/osascript

-- OmniFocus Change Tracker AppleScript
-- Exports minimal task state for change detection

on run
    try
        tell application "OmniFocus"
            if not (exists front document) then
                return "ERROR: No OmniFocus document open"
            end if
            
            set output to ""
            set taskCount to 0
            set projectCount to 0
            
            -- Get all projects
            tell front document
                repeat with proj in flattened projects
                    if (completed of proj) is false then
                        set projectCount to projectCount + 1
                        set projId to (id of proj) as string
                        set projName to (name of proj) as string
                        set projModDate to (modification date of proj) as string
                        set output to output & "PROJECT|" & projId & "|" & projName & "|" & projModDate & "\n"
                    end if
                end repeat
                
                -- Get all tasks (both in projects and inbox)
                repeat with tsk in flattened tasks
                    if (completed of tsk) is false then
                        set taskCount to taskCount + 1
                        set taskName to (name of tsk) as string
                        set taskId to (id of tsk) as string
                        set taskModDate to (modification date of tsk) as string
                        
                        -- Get project name if task is in a project
                        set projectName to "Inbox"
                        if (containing project of tsk) is not missing value then
                            set projectName to (name of (containing project of tsk)) as string
                        end if
                        
                        set output to output & "TASK|" & taskId & "|" & taskName & "|" & projectName & "|" & taskModDate & "\n"
                    end if
                end repeat
                
                -- Get completed tasks from last hour (for completion tracking)
                set oneHourAgo to (current date) - 3600
                repeat with tsk in flattened tasks
                    if (completed of tsk) is true and (completion date of tsk) > oneHourAgo then
                        set taskName to (name of tsk) as string
                        set taskId to (id of tsk) as string
                        set completionDate to (completion date of tsk) as string
                        
                        -- Get project name if task was in a project
                        set projectName to "Inbox"
                        if (containing project of tsk) is not missing value then
                            set projectName to (name of (containing project of tsk)) as string
                        end if
                        
                        set output to output & "COMPLETED|" & taskId & "|" & taskName & "|" & projectName & "|" & completionDate & "\n"
                    end if
                end repeat
            end tell
            
            -- Add summary header
            set currentDateStr to (current date) as string
            set summaryHeader to "SUMMARY|" & taskCount & "|" & projectCount & "|" & currentDateStr & "\n"
            set finalOutput to summaryHeader & output
            
            return finalOutput
            
        end tell
    on error errorMessage
        return "ERROR: " & errorMessage
    end try
end run