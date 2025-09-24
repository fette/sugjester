# Hugo Blog Integration

The Sugjester system now automatically imports your Hugo blog reading history to give the AI complete context for making intelligent recommendations.

## What It Does

- **Daily import**: Automatically adds your finished books from Hugo shelf as a "Books read" bucket
- **Rich metadata**: Imports titles, authors, completion dates, tags, and ISBN data from Hugo YAML
- **Complete context**: Gives Sugjester full reading ecosystem view for better recommendations

## Testing the Integration

### Manual Test
```bash
# Test the Hugo sync in isolation
./sync-hugo-books.sh

# Or test the full pipeline
./automate-export.sh
```

### What to Expect
- The script will log its progress to `data/export.log`
- Your finished books from Hugo shelf will be imported as a "Books read" bucket
- Your `books-to-consider.json` will include both to-read and already-read books
- Changes will be committed to git automatically

### Example Log Output
```
[2025-09-24 14:30:15] HUGO: Starting Hugo books sync...
[2025-09-24 14:30:16] HUGO: Hugo repo is up to date
[2025-09-24 14:30:16] HUGO: Extracting finished books from Hugo shelf...
[2025-09-24 14:30:17] HUGO: Found 736 finished books in Hugo shelf
[2025-09-24 14:30:17] HUGO: Adding Hugo reading history to book data...
[2025-09-24 14:30:18] HUGO: Added 736 finished books from Hugo shelf
[2025-09-24 14:30:18] HUGO: Updated books-to-consider.json: total books now 966 (including 736 read)
[2025-09-24 14:30:18] HUGO: Hugo books sync completed
```

## Data Structure

Your `books-to-consider.json` now includes four buckets:

- **"Books to consider"**: From OmniFocus - books you're thinking about reading
- **"Books owned to read"**: From OmniFocus - books you own but haven't read yet  
- **"Japanese books to consider"**: From OmniFocus - Japanese language books to consider
- **"Books read"**: From Hugo shelf - books you've finished with rich metadata

## Hugo Shelf Requirements

The integration expects your Hugo shelf files to have YAML front matter like:

```yaml
---
title: Art and Fear — Observations on the Perils (and Rewards) of Artmaking
author: David Bayles
status: Finished
finished: 2013-11-18
---
```

Only books with `status: Finished` are imported into the "Books read" bucket.

## Troubleshooting

### No Books Imported
- Check that Hugo shelf path is correct: `/Users/fet/source/metalbat/metalbat-hugo/content/shelf`
- Verify Hugo files have proper YAML front matter with `title:` and `status: Finished`
- Check the log for extraction details - books without valid titles or status are skipped

### Git Errors
- Hugo repo pull failures are logged but don't stop the sync
- The system will use local Hugo data if git operations fail

### Missing Metadata
- Books with invalid JSON in tags will fall back to empty tags array
- Books with unparseable dates will show `null` for finish date
- The system is designed to be robust and skip problematic entries rather than fail

## Customization

### Different Hugo Path
Edit `HUGO_SHELF_PATH` in `sync-hugo-books.sh`:
```bash
HUGO_SHELF_PATH="/path/to/your/hugo/content/shelf"
```

### Data Filtering
Modify the YAML extraction logic to include/exclude different book statuses or metadata fields.

### Disable Hugo Sync
Comment out the Hugo sync section in `automate-export.sh` to disable the feature.
