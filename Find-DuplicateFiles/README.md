# Find-DuplicateFiles PowerShell Script
## Description
`Find-DuplicateFiles.ps1` is a robust PowerShell script aimed at identifying and handling duplicate files within a given directory. The script uses hashing algorithms like MD5, SHA1, or SHA256 to identify duplicates. It offers a range of options such as exclusion of specific directories and file types, user confirmation for action, and more.

Moreover, the script logs significant events and can export a list of duplicate files to a CSV file. This utility can be exceptionally beneficial for system administrators looking to maintain a clean and optimized file system.

## Usage

The script can be run using either default parameters or custom values to tailor the execution as per your specific requirements.

### Parameters:
- `targetDir`: Specifies the target directory for scanning. Default is 'C:\Default\Path'.
- `hashAlgorithm`: The hashing algorithm to use. Default is 'MD5'.
- `exportPath`: The path for exporting the list of duplicate files to a CSV. Default is '.\duplicate_files.csv'.
- `logPath`: Specifies where the log files will be saved. Default is '.\file_operations.log'.
- `excludeDirs`: An array of directories to exclude from scanning.
- `excludeFileTypes`: An array of file types to exclude from scanning.
- `userConfirm`: Defines the action on duplicates ('None', 'Delete', 'Move').
- `movePath`: The directory where duplicates will be moved if `userConfirm` is set to 'Move'. Default is 'C:\DuplicateFiles'.

### Using default values:

```powershell
./Find-DuplicateFiles.ps1
```

This will run the script with all the default parameters.

### Using custom values:
```powershell
./Find-DuplicateFiles.ps1 -targetDir "C:\MyFolder" -hashAlgorithm "SHA256" -exportPath "C:\MyExports\duplicates.csv" -logPath "C:\MyLogs\log.txt" -userConfirm "Delete"
```
This example runs the script targeting the "C:\MyFolder" directory, using the SHA256 algorithm, exporting duplicates to a custom CSV location, logging to a custom location, and deleting duplicates upon user confirmation.
## Choosing a Hash Algorithm
- MD5 is fast but less secure, suitable for general use.
- SHA1 offers a balance between speed and security.
- SHA256 provides high security but is slower. Recommended for sensitive data.
## Contributing
Your contributions make this tool better. If you've found a bug or have an enhancement in mind, feel free to fork the repo, make changes, and submit a pull request.
## FAQ / Troubleshooting
- Script doesn't start? Ensure you're running PowerShell with administrative privileges.
- Hashing takes too long? Consider using a faster hash algorithm or exclude large, irrelevant directories.
## License
This script is shared under the MIT License, allowing free use, modification, and distribution.
## Author
Concept and development by Claudio Gonçalves.
