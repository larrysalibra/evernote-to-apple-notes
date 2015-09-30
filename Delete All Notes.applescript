(*
    Delete all of your Apple Notes notes
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

This worked on Apple Notes Version 4.0 (535) on OS X 10.11 (15A282b) 
It might not work on yours.

Known Issue: Deleted folders sometimes randomly reappear a short while later.
Workaround: Run the script again and/or manually delete the empty folders.

*)

tell application "Notes"
	display dialog "This script will delete all folders from a the account." & Â
		linefeed & linefeed & "This action cannot be undone." buttons {"Cancel", "I'm sure! Let's do this!"} Â
		default button 1 with icon 2
	set thisAccountName to Â
		(my getNameOfTargetAccount("Select the account from which you want to delete all folders:"))
	repeat with theFolder in folders of account thisAccountName
		delete (every note of the theFolder)
	end repeat
	
	--Rumor has it deleting these built-in folders is bad.
	delete (every folder of account thisAccountName whose name is not "Notes" and name is not "All iCloud")
	display dialog "All folders have been deleted from the account Ò" & Â
		thisAccountName & ".Ó" buttons {"Great!"} default button 1 with icon 1
end tell

on getNameOfTargetAccount(thePrompt)
	tell application "Notes"
		if the (count of accounts) is greater than 1 then
			set theseAccountNames to the name of every account
			set thisAccountName to Â
				(choose from list theseAccountNames with prompt thePrompt)
			if thisAccountName is false then error number -128
			set thisAccountName to thisAccountName as string
		else
			set thisAccountName to the name of account 1
		end if
		return thisAccountName
	end tell
end getNameOfTargetAccount