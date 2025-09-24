# Sugjester Developer Guide

## Design Philosophy

### Simple and Durable
**Core Principle**: Keep everything as simple and durable as possible.

- Prefer fewer files over many files
- Prefer simple data structures over complex ones
- Avoid premature optimization
- Choose solutions that will work for years without maintenance
- When in doubt, choose the simpler approach

### Single User Focus
**This system is built exclusively for William.**

- No need to consider multiple users, user management, or permissions
- Hardcode values when appropriate (project IDs, file paths, etc.)
- Optimize for one person's workflow, not general use cases
- Don't build abstractions for scenarios that will never happen

## Technical Standards

### JSON Structure
**All JSON files must be formatted for VS Code expand/collapse support:**

✅ **Good** - Spreadout, expandable structure:
```json
{
  "exportDate": "2025-01-15T10:30:00.000Z",
  "buckets": {
    "Books to consider": [
      {
        "title": "Some Book Title",
        "project": "Books to consider",
        "priority": "normal"
      }
    ]
  }
}
```

❌ **Bad** - Compressed, non-expandable:
```json
{"exportDate":"2025-01-15T10:30:00.000Z","buckets":{"Books to consider":[{"title":"Some Book Title","project":"Books to consider","priority":"normal"}]}}
```

**Requirements:**
- 2-space indentation
- Objects and arrays spread across multiple lines
- Each book entry as a separate, expandable object
- Proper nesting that shows clear hierarchy in VS Code's file explorer

### File Organization
**Keep the data layer simple and unified:**

- Single export file: `books-to-consider.json` (not separate language files)
- Organized buckets within one file for AI consumption
- Summary files only when they add genuine value
- Remove redundant data structures immediately

## Current Architecture

### Data Flow
1. **OmniFocus** (source of truth)
   - Three projects with hardcoded IDs
   - AppleScript extracts incomplete tasks only

2. **Export Pipeline**
   - `export-books.applescript` - Direct OmniFocus query
   - `export-books.sh` - Transform to JSON structure
   - `sync-hugo-books.sh` - Cross-reference with Hugo blog reading history
   - `automate-export.sh` - Scheduling and Git integration

3. **Output Structure**
   - `data/books-to-consider.json` - Unified export (230 books total)
   - Three buckets: Books to consider, Books owned to read, Japanese books to consider
   - Optimized for AI language balancing and ownership logic

### Project IDs (Hardcoded)
```
Books to consider:       omnifocus:///project/aCuCB0X3CYn
Books owned to read:     omnifocus:///project/gipgWMqDMdb  
Japanese books to consider: omnifocus:///project/bPvbY14zt9G
```

## Development Guidelines

### When Adding Features
1. **Start simple** - Can this be done in the existing structure?
2. **Avoid abstraction** - Don't build for theoretical future needs
3. **Test with real data** - Use William's actual OmniFocus projects
4. **JSON formatting** - Always ensure VS Code expandability

### When Refactoring
1. **Maintain simplicity** - If it's working, be very careful about changes
2. **Keep unified structure** - Resist urge to split files again
3. **Preserve durability** - Don't introduce complex dependencies

### Code Style
- Bash scripts: Clear variable names, extensive logging
- AppleScript: Follow Jon's proven patterns
- JSON: Always pretty-printed and expandable
- Comments: Explain "why" not "what"

## AI Integration Goals
The export system is designed to support intelligent recommendations:

- **Language balancing**: "You've been reading English lately, try this Japanese book"
- **Ownership logic**: "Before buying X, consider reading Y which you already own"  
- **Unified context**: AI sees all books at once for better patterns
- **Simple querying**: `data.buckets['Books owned to read']` - no complex merging

## Hugo Blog Integration

The system automatically imports your Hugo blog reading history to give the AI complete context:

- **Hugo shelf path**: `/Users/fet/source/metalbat/metalbat-hugo/content/shelf`
- **Auto-import**: Daily sync pulls Hugo blog data and adds "Books read" bucket
- **Rich metadata**: Imports titles, authors, finish dates, tags, and ISBN data
- **Complete context**: AI sees both what you want to read and what you've already read

### How It Works
1. `sync-hugo-books.sh` extracts finished books from Hugo YAML front matter
2. Converts Hugo metadata to consistent JSON format
3. Adds "Books read" bucket to existing OmniFocus buckets
4. Provides AI with complete reading ecosystem for better recommendations
5. Updates total book count to include read books

## Automation Schedule
- **Daily export**: 9:00 AM via launchd
- **OmniFocus export**: Extract current to-read lists  
- **Hugo sync**: Import reading history and add "Books read" bucket
- **Auto-commit**: Changes tracked in Git automatically
- **Error handling**: Comprehensive logging to `data/export.log`

---

## Decision Log

### Why Single Unified File?
- **Date**: 2025-09-24
- **Decision**: Consolidate separate English/Japanese files into `books-to-consider.json`
- **Reasoning**: Better for AI language balancing, eliminates redundancy, simpler structure
- **Result**: Clean 3-bucket structure, 50% smaller files, easier AI consumption

### Why Hardcoded Project IDs?
- **Date**: 2025-09-24  
- **Decision**: Use hardcoded OmniFocus project IDs instead of tag-based filtering
- **Reasoning**: More reliable, faster queries, William's projects are stable
- **Result**: Robust export system, no dependency on tag consistency

### Why No flatList?
- **Date**: 2025-09-24
- **Decision**: Remove redundant flatList from JSON exports
- **Reasoning**: AI can easily flatten buckets if needed: `Object.values(data.buckets).flat()`
- **Result**: Cleaner JSON, no data duplication, file size cut in half

### Why Hugo Blog Integration?
- **Date**: 2025-09-24
- **Decision**: Add automatic import of Hugo blog reading history as "Books read" bucket
- **Reasoning**: Give AI complete reading context without modifying to-read lists; enables better recommendations
- **Result**: AI has full reading ecosystem view: to-consider + owned + already-read for intelligent suggestions
