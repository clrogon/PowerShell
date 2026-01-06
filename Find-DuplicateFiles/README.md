# Find-DuplicateFiles PowerShell Script
## Description
`Find-DuplicateFiles.ps1` is a robust PowerShell script aimed at identifying and handling duplicate files within a given directory. The script uses hashing algorithms like SHA256, SHA1, or SHA512 to identify duplicates. It offers a range of options such as exclusion of specific directories and file types, user confirmation for action, and more.

Moreover, the script logs significant events and can export a list of duplicate files to a CSV file. This utility can be exceptionally beneficial for system administrators looking to maintain a clean and optimized file system.

## 🔒 Security Features

This script implements comprehensive security measures:

- **Strong Cryptography**: Default algorithm changed to SHA256 for security
- **Path Traversal Protection**: Validates all file paths to prevent directory traversal attacks
- **Input Validation**: Sanitization of all user inputs including file extensions
- **Secure File Operations**: Proper error handling and validation before file modifications
- **Extension Validation**: Only allows valid file extensions in exclusion lists

### Security Best Practices Implemented

1. **SHA256 Default**: Uses secure hashing by default (previously MD5)
2. **Path Sanitization**: Prevents access to unauthorized directories
3. **Extension Validation**: Blocks malicious file extension patterns
4. **Safe Defaults**: Secure settings enforced by default

## Usage

The script can be run using either default parameters or custom values to tailor the execution as per your specific requirements.

### Parameters:
- `targetDir`: Specifies the target directory for scanning. Default is 'C:\Default\Path'.
- `hashAlgorithm`: The hashing algorithm to use. Options: SHA256, SHA1, SHA384, SHA512, MD5. Default is 'SHA256'.
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
- **SHA256** (Default): Provides high security and is recommended for most use cases. Cryptographically strong and collision-resistant.
- **SHA384/SHA512**: Offers even higher security for extremely sensitive applications, though slightly slower.
- **SHA1**: Provides moderate security but faster processing. Not recommended for new deployments.
- **MD5**: Fast but cryptographically weak. Use only for non-security-critical tasks (legacy support).

> [!IMPORTANT]
> **Security Note**: SHA256 is the default algorithm for security. MD5 and SHA1 are deprecated for security purposes and should only be used for non-critical legacy applications.
## Contributing
Your contributions make this tool better. If you've found a bug or have an enhancement in mind, feel free to fork the repo, make changes, and submit a pull request.
## FAQ / Troubleshooting
- Script doesn't start? Ensure you're running PowerShell with administrative privileges.
- Hashing takes too long? Consider using a faster hash algorithm or exclude large, irrelevant directories.
## License
This script is shared under the MIT License, allowing free use, modification, and distribution.
## Author
Concept and development by Claudio Gonçalves.
