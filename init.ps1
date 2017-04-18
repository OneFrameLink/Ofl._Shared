param (
	[string]$project
)
#git submodule add https://github.com/OneFrameLink/Ofl._Shared.git _Shared

# The root
$root = (Get-Item -Path ".\" -Verbose).FullName

# The path.
$path = $root + "\" + $project

# Write-Host
Write-Host "Project: $project"
Write-Host "Root: $root"
Write-Host "Path: $path"
Write-Host

# Delete the directory if it exists.
Write-Host "Starting removal of directory $path"
Remove-Item $project -recurse
Write-Host "Removal of directory $path complete"
Write-Host

Write-Host
Write-Host "Starting initialization of project"

# Clone into project directory
git clone "https://github.com/OneFrameLink/$project.git"

# Set location.
Set-Location -Path $path

# Initialize git.
git config user.name casperOne
git config user.email casperOne@caspershouse.com
git submodule add https://github.com/OneFrameLink/Ofl._Shared.git _shared

# Copy items out of _shared
Copy-Item .\_shared\.gitignore $path
Copy-Item .\_shared\appveyor.yml $path
Copy-Item .\_shared\directory.build.props $path

# The test project.
$testProject = "$project.Tests"

# The source and test paths.
$srcPath = "$path\src\$project"
$testPath = "$path\test\$testProject"

# Create the source and test subdirectories
New-Item $srcPath -type  directory
New-Item $testPath -type  directory

# Create the solution
dotnet new sln

# Create the project.
dotnet new classlib -f netstandard1.3 -o $srcPath -n $project

# Create the test project.
dotnet new xunit -f netcoreapp1.1 -o $testPath -n $testProject

explorer .

Set-Location -Path $root

Write-Host "Initialization of project complete"