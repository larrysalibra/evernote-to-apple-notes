(*
Export Evernote notes to Apple Notes
Copyright (C) 2015  Lawrence A. Salibra, III

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

======	

Read https://www.larrysalibra.com/evernote-to-apple-notes/ and then
https://www.larrysalibra.com/can-apple-notes-replace-evernote/ *before* 
you run this. You have been warned.

======

This worked on Evernote Version 6.1.1 (452254 App Store) 
and Apple Notes Version 4.0 (535) on OS X 10.11 (15A284) 
It might not work on yours.

Known Issue: Migrating too many notes at one time may cause Evernote to time out. 
Workaround: Migrate notes in smaller batches. 
	
*)
----------
-- User configurable settings
----------

(*
Appends Evernote data that can't be set in Apple Notes such as
creation date & location in JSON structured text at end of note
*)
set includeEvernoteData to true


set timeoutInMinutes to 120

----------
-- Nothing user configurable below this line
----------
with timeout of (timeoutInMinutes * 60) seconds
	
	set username to (system attribute "USER")
	
	-- Sandboxing limits access to apps' own containers
	set exportFolder to "Users:" & username & ":Library:Containers:com.evernote.Evernote:Data:attachment_export:" as string
	set importFolder to "Users:" & username & ":Library:Containers:com.apple.Notes.HTMLConverter:Data:import:" as string
	
	tell application "System Events"
		set exportFolderPosix to (POSIX path of folder exportFolder) & "/"
		set importFolderPosix to (POSIX path of folder importFolder) & "/"
	end tell
	
	do shell script "mkdir -p " & quoted form of exportFolderPosix
	do shell script "mkdir -p " & quoted form of importFolderPosix
	
	-- Clean out any attachments that may be left over from previous failed run
	do shell script "rm -f " & quoted form of importFolderPosix & "*"
	do shell script "rm -f " & quoted form of exportFolderPosix & "*"
	
	tell application "Evernote"
		set selectedNotes to selection
		set migratedNoteCount to 0
		repeat with theNote in selectedNotes
			set noteName to title of theNote
			set noteBody to HTML content of theNote
			set noteNotebookName to name of notebook of theNote
			
			-- data that we can't use directly in Apple Notes
			set noteSource to (source URL of theNote)
			set noteCreated to (creation date of theNote)
			set noteModified to (modification date of theNote)
			set noteTags to (tags of theNote)
			set noteAltitude to (altitude of theNote)
			set noteLat to (latitude of theNote)
			set noteLong to (longitude of theNote)
			
			set unnamedCounter to 1
			
			repeat with theAttachment in (attachments of theNote)
				do shell script "rm -f " & quoted form of importFolderPosix & "*"
				
				set theFilename to theAttachment's filename
				
				if theFilename is equal to missing value then
					--assume attachments without filenames are jpg photos take with evernote ios app
					set theFilename to "photo-" & unnamedCounter & ".jpg"
					set unnamedCounter to unnamedCounter + 1
				end if
				set fileExists to false
				
				tell application "System Events"
					if exists file (exportFolder & theFilename) then
						set fileExists to true
					end if
				end tell
				
				if not fileExists then
					write theAttachment to (exportFolder & theFilename)
				else
					-- prepend a random number to avoid filename collisions 
					set theFilename to (random number from 1 to 100) & "-" & theFilename
					write theAttachment to (exportFolder & theFilename)
				end if
				
				-- Evernote references every attachment with a img or embed tag 
				-- where src=?hash=<md5 hash of the attachment>
				set evernoteProvidedHash to hash of theAttachment
				set attachmentHash to do shell script ("md5 -q " & quoted form of (exportFolderPosix & theFilename))
				if evernoteProvidedHash is not equal to attachmentHash then
					display dialog "Uh oh! There appears to be data corruption while exporting the attachment: " & theFilename
				end if
				
				set evernoteSrc to "?hash=" & attachmentHash
				set notesSrc to "file://" & importFolderPosix & theFilename
				
				set sedEscapeReplaceComand to "sed -e 's/[\\/&]/\\\\&/g'"
				
				set notesSrc to do shell script "echo " & (quoted form of notesSrc) & " | " & sedEscapeReplaceComand
				
				set shellText to "echo " & (quoted form of noteBody) & " | sed 's/?hash=" & attachmentHash & "/" & notesSrc & "/g'"
				try
					set noteBody to do shell script shellText
				on error
					display dialog "There was a problem migrating an attachment. The next 3 dialogs will display some info that might help you solve the problem. Keep clicking ok to continue the migration progress or cancel to stop."
					display dialog noteBody
					display dialog attachmentHash
					display dialog notesSrc
				end try
				
				
				-- Replace Evernote embed tags with img
				-- Apple Notes treats any file referenced in img tag as attachment
				set shellText to "echo " & (quoted form of noteBody) & " | sed 's,<embed,<img,g'"
				set noteBody to do shell script shellText
				
			end repeat
			
			if includeEvernoteData is equal to true then
				set evernoteData to "<pre>{"
				set evernoteData to evernoteData & "\"source\":  \"" & noteSource & "\", "
				set evernoteData to evernoteData & "\"created\": \"" & noteCreated & "\", "
				set evernoteData to evernoteData & "\"modified\": \"" & noteModified & "\", "
				set noteTagsText to ""
				
				set tagCounter to 0
				repeat with noteTag in noteTags
					set tagCounter to tagCounter + 1
					
					if tagCounter is equal to (count of noteTags) then
						-- don't add a common after last tag
						set noteTagsText to noteTagsText & (name of noteTag)
					else
						set noteTagsText to noteTagsText & (name of noteTag & ", ")
					end if
				end repeat
				
				set evernoteData to evernoteData & "\"tags\": \"" & noteTagsText & "\", "
				set evernoteData to evernoteData & "\"altitude\": \"" & noteAltitude & "\", "
				set evernoteData to evernoteData & "\"latitude\": \"" & noteLat & "\", "
				set evernoteData to evernoteData & "\"longitude\": \"" & noteLong & "\" }"
				
				set noteBody to noteBody & "<br><h3>Evernote Data:</h3>" & evernoteData
			end if
			
			if (count of attachments of theNote) is not equal to 0 then
				do shell script "mv " & quoted form of exportFolderPosix & "* " & quoted form of importFolderPosix
			end if
			
			tell application "Notes"
				
				if (count of accounts) is not equal to 1 then
					display dialog "This script only supports 1 Notes account. It will now stop!"
					error number -128
				end if
				set theAccount to item 1 of accounts
				
				if not (exists folder noteNotebookName) then
					make new folder with properties {name:noteNotebookName} at theAccount
				end if
				
				set newNote to make new note at folder noteNotebookName with properties {name:noteName, body:noteBody}
				
			end tell
			
			set migratedNoteCount to migratedNoteCount + 1
			
		end repeat
		display dialog "Migrated " & migratedNoteCount & " notes"
	end tell
	
end timeout