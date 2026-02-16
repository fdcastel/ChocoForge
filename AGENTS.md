# This shell is PowerShell 7.5

- use `pwsh` as shell
- Command separator is ';', not '&&'.
- Use `./tmp` folder for any temporary files or scripts you need. This folder is on `.gitignore`.

# This project code is for Windows PowerShell 7.5

- You don't need to keep backwards compatibility with Windows PowerShell 5.1.
- Keep one function per file, unless the functions are closely related.


## About strings

- Use single quotes for literal strings
- Use double quotes for interpolated strings  
- Always use `$()` wrapper for variable interpolation
- Use backtick (`` ` ``) for escaping in double-quoted strings
- Double quotes for escaping in single-quoted strings
- Never use backslash (`\`) as escape character
- Avoid double backslashes (`\\`) in paths. Use forward slashes (`/`) instead.
- Use Powershell here-strings for complex multi-line content
- Test string output to verify correct interpretation


# Verbose / debugging

- Verbose outputs are for debugging.  
- Include verbose messages that may help with future debugging. But do not to overdo it.
- Ensure all non-throwing if statements include a `Write-VerboseMark` call to output appropriate messages for debugging. This ensures better traceability of conditional logic during execution.
- Always use the Write-VerboseMark function to produce verbose messages.
