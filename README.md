# CWManageHuduLocationSync
This is used to sync locations from Manage to Hudu to help assign documentation and assets to a location.

## Hudu Setup
If you have a locations asset layout already, please reference the exported JSON file to identify which fields should be marked required so the comparison works correctly.

If you do not have one, use this JSON file to import one.

You will also need to add a CWManageID field which gets used to assign the location ID from Manage to the location asset in Hudu.

Please review lines 31 and 32 so you can set the Asset Layout for Locations in Hudu.

# Script Runtime
This script runs for a LONG time, as it goes through in depth comparisons and is not efficient.

When running the script it'll create or find a folder for the log file, and then dump a transcript of the script run time into the folder.

To ensure highest success we keyed off several fields in Hudu to ensure best matching and we "fail close" where we don't update at all if a match isn't found.

If you have existing locations, note that this script will generate brand new ones, so you'll want to set the ID from Manage in Hudu into the new field on the layout, this will prevent it from creating duplicates.
