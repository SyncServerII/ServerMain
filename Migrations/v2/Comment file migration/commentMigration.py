import json
import datetime
from os import listdir
from os.path import isfile, join

# Migrate userId's, i.e., senderId's in Neebla/SyncServerII comment files.
# See https://github.com/SyncServerII/Neebla/issues/14

# Date time string conversions: https://stackabuse.com/converting-strings-to-datetime-in-python/

# The date range of comments, from the beta test, we're trying to migrate.
migrationStartDate = datetime.datetime.strptime("2021-01-28", "%Y-%m-%d")
migrationEndDate = datetime.datetime.strptime("2021-05-27", "%Y-%m-%d")
print("Migrating comments from", migrationStartDate, "to", migrationEndDate)

# Apply migrations to a single comment file, if needed by that comment file.
# First, checks to make sure the file is a JSON file and that the file is a comment file.
# Returns True if migration applied; False if not.
def migrateCommentFile(commentFileName):
    # Reading/writing file: https://stackoverflow.com/questions/6648493/how-to-open-a-file-for-both-reading-and-writing
    file = open(commentFileName, "r+")
    fileContents = file.read()
    senderIdKey = "senderId"

    migrationKey = "Migration"
    commentMigrationValue = "1"
     
    # try/except to make sure this is JSON
    try:
        fileJSON = json.loads(fileContents)
    except ValueError:
        print("Warning: File didn't contain JSON: Not attempting migration:", commentFileName)
        return False

    # `elements` is a dictionary that contains all of the commments
    elementsKey = "elements"
    
    if elementsKey not in fileJSON:
        print("Warning: File was JSON but didn't have comments: Not attempting migration:", commentFileName)
        return False
    
    commentDictionary = fileJSON[elementsKey]

    migrationChange = False

    for comment in commentDictionary:
        # I'm also going to add in a new key/value pair when a migration change is applied.
        # So that the migration isn't attempted twice.
        if migrationKey in comment:
            print("Comment already migrated; skipping.")
            continue
            
        # Check to see if this comment is in a date range indicating it was part of
        # the Neebla v2 beta test.
        # Example `sendDate`: "sendDate": "2021-05-24T22:28:36Z",
        sendDateString = comment["sendDate"]
        sendDate = datetime.datetime.strptime(sendDateString, "%Y-%m-%dT%H:%M:%SZ")

        if sendDate < migrationStartDate or sendDate > migrationEndDate:
            # Don't migrate this comment; it wasn't created during the beta testing period.
            continue

        # senderId migration:
        #   2 -> 3 (Rod)
        #   3 -> 4 (Dany)

        senderId = comment[senderIdKey]
        if senderId == "2":
            comment[senderIdKey] = "3"
            comment[migrationKey] = commentMigrationValue
            migrationChange = True
        elif senderId == "3":
            comment[senderIdKey] = "4"
            comment[migrationKey] = commentMigrationValue
            migrationChange = True
            
    if migrationChange:
        # print("Applied migration change(s); writing updated file")
        jsonResultString = json.dumps(fileJSON)
        
        # Write updated contents back to same file
        file.seek(0)
        file.write(jsonResultString)
        file.truncate()

    file.close()
    
    return migrationChange

# Perform the migration. This does:
# 1) Gets a list of file names from the current directory.
# 2) Filters that list for only text files.
# 3) Applies migration to those files.
def migrate():
    mypath = "."
    # From https://stackoverflow.com/questions/3207219/how-do-i-list-all-files-of-a-directory
    allfiles = [f for f in listdir(mypath) if isfile(join(mypath, f))]
    # print(allfiles)
    onlyTextFiles = []
    for file in allfiles:
        if file.endswith(".txt"):
            onlyTextFiles.append(file)
    
    numberFilesMigrated = 0
    numberFilesNotMigrated = 0

    for textFile in onlyTextFiles:
        if migrateCommentFile(textFile):
            numberFilesMigrated += 1
        else:
            numberFilesNotMigrated += 1
    
    print(numberFilesMigrated, "migrations successfully applied")
    print(numberFilesNotMigrated, "migrations not applied (e.g., not in date range)")


migrate()

# ExampleFile = "FD1FB0FC-19E4-449C-8D7F-A3542DC1C6DC.E09DA64C-BA1C-46ED-8A2B-1F03C23464EB.4.json"

#if migrateCommentFile(ExampleFile):
#    print("Migration applied")
#else:
#    print("Migration *NOT* applied")

# migrateCommentFile("NotJSON.txt")
# migrateCommentFile("jsonNotComments.txt")


