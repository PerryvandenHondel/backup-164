//
// Backup
//
// 164
//



program backup;



{$MODE OBJFPC}			// Create a Free Pascal Object file.
{$LONGSTRINGS ON}		// Compile all strings as Ansistring



uses
	DateUtils,
	Process, 
	SysUtils,
	USupportLibrary;

	

const
	CONF_NAME = 								'backup.conf';
	BACKUP_TYPE_FULL = 							1;
	BACKUP_TYPE_INCR = 							2;
	EXTENSION_BACKUP = 							'.rar';
	

	
type
	RFolder = record
		path: Ansistring;
		//timeStamp: Longint;
	end;
	TFolder = Array of RFolder;



var
	pathPid: Ansistring;
	pathConfig: Ansistring;
	afr: TFolder;
	
	
	
procedure DeleteDirectory(const Name: string);
var
  F: TSearchRec;
begin
  if FindFirst(Name + '\*', faAnyFile, F) = 0 then begin
    try
      repeat
        if (F.Attr and faDirectory <> 0) then begin
          if (F.Name <> '.') and (F.Name <> '..') then begin
            DeleteDirectory(Name + '\' + F.Name);
          end;
        end else begin
          DeleteFile(Name + '\' + F.Name);
        end;
      until FindNext(F) <> 0;
    finally
      FindClose(F);
    end;
    RemoveDir(Name);
  end;
end; // of DeleteDirectory



procedure KeepNewestFolders(const inThisDirectory: Ansistring; keepNumber: integer);
var
	sr: TSearchRec;
	size: integer;
	x: integer;
	folderCount: integer;
begin
	WriteLn('The folder ', inThisDirectory, ' contains the following sub-folders:');
	
	if FindFirst(FixFolderAdd(inThisDirectory) + '*', faAnyFile and faDirectory, sr) = 0 then
    begin
		repeat
			with sr do
			begin
				if ((sr.Attr and faDirectory) = faDirectory) and (sr.Name <> '.') and (sr.Name <> '..') then
				begin
					WriteLn(sr.Name, '      ', sr.Time);
					
					size := Length(afr);
					SetLength(afr, size + 1);
					afr[size].path := sr.Name;
				end;
			end;
		until FindNext(sr)<>0;
    end;
	FindClose(sr);
	
	
	folderCount := 0;
	for x := (Length(afr) - 1) downto 0 do
	begin
		Inc(folderCount);
		if folderCount > keepNumber then
		begin
			WriteLn(folderCount:3, '    ', FixFolderAdd(inThisDirectory) + afr[x].Path, ' DELETE');
			DeleteDirectory(FixFolderAdd(inThisDirectory) + afr[x].Path);
		end
		else
			WriteLn(folderCount:3, '    ', FixFolderAdd(inThisDirectory) + afr[x].Path, ' KEEPING');
	end;
end; // of KeepNewestFolders



function CountSubDirectories(inThisDirectory: Ansistring): integer;
//
// Count the number of sub directories in starting directory inThisDirectory
//
// Based on: 
//		http://www.swissdelphicenter.ch/torry/showcode.php?id=1125
//		http://www.freepascal.org/docs-html/rtl/sysutils/findfirst.html
//
var
	counter: integer;
	sr: TSearchRec;
begin
	counter := 0;
	if FindFirst(FixFolderAdd(inThisDirectory) + '*',faAnyFile and faDirectory, sr) = 0 then
    begin
		repeat
			with sr do
			begin
				if ((sr.Attr and faDirectory) = faDirectory) and (sr.Name <> '.') and (sr.Name <> '..') then
				begin
					Inc(counter);
				end;
			end;
		until FindNext(sr)<>0;
    end;
	FindClose(sr);
	CountSubDirectories := counter;
end;



function ExecuteCommand(strCommand: Ansistring): integer;
//
//	Run a command using the CMD.EXE interpreter, 
//	returns the error level as the result of this function.
//
var
	p: TProcess;		// Uses Process
begin
	p := TProcess.Create(nil);
	p.Executable := 'cmd.exe'; 
    p.Parameters.Add('/c ' + strCommand);
	// Options:
	//	poWaitOnExit: //
	//	poNoConsole:
	//	poUsePipes: 
	p.Options := [poWaitOnExit];
	//p.Options := [poWaitOnExit, poNoConsole];
	p.Execute;
	
	Result := p.ExitStatus;
	p.Free;
end; // of function RunCommand.





function MakeBackup(setName: Ansistring; folderSource: Ansistring; folderBackupSetFullDate: Ansistring; backupType: integer): integer;
//
//	Make a backup and return the error level back to calling procedure.
//
var
	pathBackupFile: Ansistring;
	c: Ansistring;
	rc: integer;
	preAction: Ansistring;
	postAction: Ansistring;
begin
	WriteLn;
	
	pathBackupFile := FixFolderAdd(folderBackupSetFullDate) + 'backup' + EXTENSION_BACKUP;
	
	WriteLn('MakeBackup():');
	WriteLn(#9, 'Set name             : ', setName);
	WriteLn(#9, 'Folder source        : ', folderSource);
	WriteLn(#9, 'File to backup to    : ', pathBackupFile);
	if backupType = BACKUP_TYPE_FULL then
		WriteLn(#9, 'Type of Backup       : FULL');
		
	if backupType = BACKUP_TYPE_INCR then
		WriteLn(#9, 'Type of Backup       : INCREMENTAL');
		
	preAction := ReadSettingKey(pathConfig, setName, 'ActionsPre');
	if Length(preAction) > 0 then
	begin
		WriteLn;
		WriteLn('Run the pre backup actions: ', preAction);
		WriteLn;
		
		RunCommand(preAction);
	end;
	
	MakeFolderTree(pathBackupFile);
	
	c := 'rar.exe';
	c := c + ' ';
	c := c + 'a'; // Action is Add
	c := c + ' ';
	c := c + '-r'; // Recusive folders
	c := c + ' ';
	c := c + '-m0';  // 0=Store...5=max compression
	c := c + ' ';
	c := c + '-ep2'; // Expand paths to the full length
	c := c + ' ';
	if backupType = BACKUP_TYPE_FULL then
		c := c + '-ac' // Clear archive bit after compression.
	else 
		c := c + '-ao'; // Add file with archive bit on.
	c := c + ' ';
	c := c + EncloseDoubleQuote(pathBackupFile);
	c := c + ' ';
	c := c + EncloseDoubleQuote(FixFolderAdd(folderSource) + '*.*');
	
	WriteLn;
	WriteLn('Running command line:');
	WriteLn;
	WriteLn(c);
	WriteLn;
	
	rc := ExecuteCommand(c);
	
	WriteLn;
	
	postAction := ReadSettingKey(pathConfig, setName, 'ActionsPost');
	if Length(postAction) > 0 then
	begin
		WriteLn;
		WriteLn('Run the post backup actions: ', postAction);
		WriteLn;
		
		RunCommand(postAction);
	end;
	
	MakeBackup := rc;
end;



procedure SelectBackup(setName: Ansistring; folderSource: Ansistring; folderBackup: Ansistring; keepFull: integer; keepIncr: integer);
var
	folderBackupSetFull: Ansistring;
	folderBackupSetIncr: Ansistring;
	folderBackupSetFullDate: Ansistring;
	folderBackupSetIncrDate: Ansistring;
	countFull: integer;
	countIncr: integer;
	rc: integer;
begin
	WriteLn;
	WriteLn('SelectBackup():');
	WriteLn('                  Set name : ', setName);
	WriteLn('             Folder source : ', folderSource);
	WriteLn('             Folder Backup : ', folderBackup);
	WriteLn('         Keep full backups : ', keepFull);
	WriteLn('  Keep incremental backups : ', keepIncr);
	
	folderBackupSetFull := FixFolderAdd(folderBackup) + FixFolderAdd(setName) + 'full';
	MakeFolderTree(folderBackupSetFull);
	
	folderBackupSetIncr := FixFolderAdd(folderBackup) + FixFolderAdd(setName) + 'incr';
	MakeFolderTree(folderBackupSetIncr);
	
	folderBackupSetFullDate := FixFolderAdd(folderBackupSetFull) + GetDateFs(false) + '-' + GetTimeFs();
	folderBackupSetIncrDate := FixFolderAdd(folderBackupSetIncr) + GetDateFs(false) + '-' + GetTimeFs();
	
	countFull := CountSubDirectories(folderBackupSetFull);
	WriteLn('Found full backups is ', folderBackupSetFull, ': ', countFull);
	if countFull = 0 then
	begin
		WriteLn('INFO: No backups found, first backup is a full.');
		MakeBackup(setName, folderSource, folderBackupSetFullDate, BACKUP_TYPE_FULL);
	end
	else
	begin
		countIncr := CountSubDirectories(folderBackupSetIncr);
		if countIncr < keepIncr Then
		begin	
			WriteLn('INFO: Need more incremental backups, have ', countIncr, ' incrememtals found and need ', keepIncr, ' incrememtal backups');
			rc := MakeBackup(setName, folderSource, folderBackupSetIncrDate, BACKUP_TYPE_INCR);
			if rc = 0 then
				WriteLn('INFO: Incremental backup successfully!')
			else
				WriteLn('WARN: Incremental backup returned a code: ', rc);
		end
		else if countIncr >= keepIncr then
		begin
			WriteLn('INFO: I have enough incremental backups, make a full again');
			rc := MakeBackup(setName, folderSource, folderBackupSetFullDate, BACKUP_TYPE_FULL);
			if rc = 0 then
			begin
				WriteLn('INFO: Full backup successfully!, delete all incremental backups.');
				WriteLn('Delete the with all increamental backups: ' + folderBackupSetIncr);
				DeleteDirectory(folderBackupSetIncr);
				
				countFull := CountSubDirectories(folderBackupSetFull);
				if countFull > keepFull then
				begin
					WriteLn('The are ', countFull, ' full backups available, only need to keep ', keepFull, ', older backups can be deleted!');
					KeepNewestFolders(folderBackupSetFull, keepFull);
				end;
			end
			else
				WriteLn('WARN: Full backup returned a code: ', rc);
		end;
	end;
end;



procedure ProcessSingleBackupSet(setName: Ansistring);
var
	isActive: boolean;
	folderSource: Ansistring;
	folderBackup: Ansistring;
	keepFull: integer;
	keepIncr: integer;
begin
	WriteLn;
	WriteLn('ProcessSingleBackupSet(): ', setName);
	
	isActive := StrToBool(ReadSettingKey(pathConfig, setName, 'Active'));
	if isActive = false then
		Exit;
	
	WriteLn(setName, ' IS AN ACTIVE SET');
	
	folderSource := ReadSettingKey(pathConfig, setName, 'FolderSource');
	folderBackup := ReadSettingKey(pathConfig, setName, 'FolderBackup');
	keepFull := StrToInt(ReadSettingKey(pathConfig, setName, 'KeepFull'));
	keepIncr := StrToInt(ReadSettingKey(pathConfig, setName, 'KeepIncr'));
	
	SelectBackup(setName, folderSource, folderBackup, keepFull, keepIncr);
end;
	
procedure ProgInit();
begin
	pathPid := GetPathOfPidFile();
	pathConfig := GetProgramFolder() + '\' + CONF_NAME;
end;



procedure ProgDone();
begin
	DeleteFile(pathPid);
end;



procedure ProgRun();
begin
	if ParamCount() = 0 then
	begin
		WriteLn('Usage: ' + ParamStr(0) + ' <BACKUP-SET>');
		ProgDone();
	end
	else
	begin
		ProcessSingleBackupSet(ParamStr(1));
	end;
	//WriteLn('Number of sub directories of D:\TEMP: ', CountSubDirectories('D:\TEMP\'));
end;


	
begin
	ProgInit();
	ProgRun();
	ProgDone();
	//KeepNewestFolders('D:\BACKUPS\VM70AS006-EXPORT\full', 7);
end.