#!/usr/bin/osascript

-- Sugjester Book Export AppleScript
-- Based on Jon's proven approach

on run
    try
        tell application "OmniFocus"
            if not (exists front document) then
                return "ERROR: No OmniFocus document open"
            end if
            
            set output to ""
            set totalBooks to 0
            
            tell front document
                -- Export Books to Consider project (aCuCB0X3CYn)
                repeat with proj in flattened projects
                    set projId to (id of proj) as string
                    if projId contains "aCuCB0X3CYn" then
                        set output to output & "PROJECT_START|Books to consider|english|aCuCB0X3CYn" & linefeed
                        
                        repeat with tsk in flattened tasks of proj
                            if (completed of tsk) is false then
                                set totalBooks to totalBooks + 1
                                set taskName to (name of tsk) as string
                                set taskId to (id of tsk) as string
                                set dateAdded to (creation date of tsk) as string
                                set taskNotes to ""
                                try
                                    set taskNotes to (note of tsk) as string
                                end try
                                
                                set priority to "normal"
                                if taskName contains "⭐️" or taskName contains "@high-priority" then
                                    set priority to "high"
                                end if
                                
                                set output to output & "BOOK|" & taskId & "|" & taskName & "|" & priority & "|" & dateAdded & "|" & taskNotes & "|" & "|" & "|" & linefeed
                            end if
                        end repeat
                        set output to output & "PROJECT_END" & linefeed
                        exit repeat
                    end if
                end repeat
                
                -- Export Books Owned to Read project (gipgWMqDMdb)
                repeat with proj in flattened projects
                    set projId to (id of proj) as string
                    if projId contains "gipgWMqDMdb" then
                        set output to output & "PROJECT_START|Books owned to read|english|gipgWMqDMdb" & linefeed
                        
                        repeat with tsk in flattened tasks of proj
                            if (completed of tsk) is false then
                                set totalBooks to totalBooks + 1
                                set taskName to (name of tsk) as string
                                set taskId to (id of tsk) as string
                                set dateAdded to (creation date of tsk) as string
                                set taskNotes to ""
                                try
                                    set taskNotes to (note of tsk) as string
                                end try
                                
                                set priority to "normal"
                                if taskName contains "⭐️" or taskName contains "@high-priority" then
                                    set priority to "high"
                                end if
                                
                                set output to output & "BOOK|" & taskId & "|" & taskName & "|" & priority & "|" & dateAdded & "|" & taskNotes & "|" & "|" & "|" & linefeed
                            end if
                        end repeat
                        set output to output & "PROJECT_END" & linefeed
                        exit repeat
                    end if
                end repeat
                
                -- Export Japanese Books project (bPvbY14zt9G)
                repeat with proj in flattened projects
                    set projId to (id of proj) as string
                    if projId contains "bPvbY14zt9G" then
                        set output to output & "PROJECT_START|Japanese books to consider|japanese|bPvbY14zt9G" & linefeed
                        
                        repeat with tsk in flattened tasks of proj
                            if (completed of tsk) is false then
                                set totalBooks to totalBooks + 1
                                set taskName to (name of tsk) as string
                                set taskId to (id of tsk) as string
                                set dateAdded to (creation date of tsk) as string
                                set taskNotes to ""
                                try
                                    set taskNotes to (note of tsk) as string
                                end try
                                
                                set priority to "normal"
                                if taskName contains "⭐️" or taskName contains "@high-priority" then
                                    set priority to "high"
                                end if
                                
                                set output to output & "BOOK|" & taskId & "|" & taskName & "|" & priority & "|" & dateAdded & "|" & taskNotes & "|" & "|" & "|" & linefeed
                            end if
                        end repeat
                        set output to output & "PROJECT_END" & linefeed
                        exit repeat
                    end if
                end repeat
                
            end tell
            
            -- Add summary
            set currentDateStr to (current date) as string
            set summaryHeader to "EXPORT_SUMMARY|" & totalBooks & "|" & currentDateStr & linefeed
            set finalOutput to summaryHeader & output
            
            return finalOutput
            
        end tell
    on error errorMessage
        return "ERROR: " & errorMessage
    end try
end run
