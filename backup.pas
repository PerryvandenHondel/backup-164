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
	EXTENSION_BACKUP = 							'.7z';
	
	
var
	pathPid: Ansistring;
	pathConfig: Ansistring;
	

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


procedure MakeBackup(setName: Ansistring; folderSource: Ansistring; folderBackupSetFullDate: Ansistring; backupType: integer);
var
	pathBackupFile: Ansistring;
	c: Ansistring;
begin
	WriteLn;
	
	pathBackupFile := FixFolderAdd(folderBackupSetFullDate) + 'backup' + EXTENSION_BACKUP;
	
	WriteLn('MakeBackup():');
	WriteLn(#9, 'Set name             : ', setName);
	WriteLn(#9, 'Folder source        : ', folderSource);
	WriteLn(#9, 'File to backup to    : ', pathBackupFile);
	WriteLn(#9, 'Type of Backup       : ', backupType);
	
	MakeFolderTree(pathBackupFile);
	
	//c := '
end;


procedure SelectBackup(setName: Ansistring; folderSource: Ansistring; folderBackup: Ansistring; keepFull: integer; keepIncr: integer);
var
	folderBackupSetFull: Ansistring;
	folderBackupSetFullDate: Ansistring;
	countFull: integer;
begin
	WriteLn;
	WriteLn('SelectBackup():');
	WriteLn(#9, 'Set name                 : ', setName);
	WriteLn(#9, 'Folder source            : ', folderSource);
	WriteLn(#9, 'Folder Backup            : ', folderBackup);
	WriteLn(#9, 'Keep full backups        : ', keepFull);
	WriteLn(#9, 'Keep incremental backups : ', keepIncr);
	
	folderBackupSetFull := FixFolderAdd(folderBackup) + FixFolderAdd(setName) + 'full';
	MakeFolderTree(folderBackupSetFull);
	
	countFull := CountSubDirectories(folderBackupSetFull);
	
	WriteLn('Found full backups is ', folderBackupSetFull, ': ', countFull);
	
	if countFull = 0 then
	begin
		folderBackupSetFullDate := FixFolderAdd(folderBackupSetFull) + GetDateFs(false) + '-' + GetTimeFs();
		MakeBackup(setName, folderSource, folderBackupSetFullDate, BACKUP_TYPE_FULL);
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


procedure ProgRun();
var
	setList: Ansistring;
	setArray: TStringArray;
	x: integer;
begin
	setList := ReadSettingKey(pathConfig, 'Settings', 'Sets');
	
	SetLength(setArray, 0);   
	setArray := SplitString(setList, ',');
	for x := 0 to High(setArray) do
	begin
		//WriteLn(x, ': ', #9, LogsArray[x]);
		ProcessSingleBackupSet(setArray[x]);
	end;
	
	WriteLn('Number of sub directories of D:\TEMP: ', CountSubDirectories('D:\TEMP\'));
end;


procedure ProgDone();
begin
	DeleteFile(pathPid);
end;

	
begin
	ProgInit();
	ProgRun();
	ProgDone();
end.