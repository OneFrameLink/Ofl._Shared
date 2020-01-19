param (
	[string]$project
)

function InitializeGit([string] $project, [string] $path) {

    # Clone into project directory
    git clone "https://github.com/OneFrameLink/$project.git"

    # Set location.
    Set-Location -Path $path

    # Initialize git.
    git config user.name casperOne
    git config user.email casperOne@caspershouse.com
    git submodule add https://github.com/OneFrameLink/Ofl._Shared.git _shared
}

function CopyShared([string] $path, [string] $project) {
    # Copy items out of _shared
    Copy-Item .\_shared\.gitignore $path
    Copy-Item .\_shared\appveyor.yml $path
    Copy-Item .\_shared\directory.build.props $path
    Copy-Item .\_shared\solution $path\\$project.sln
    Copy-Item .\_shared\sln.DotSettings $path\\$project.sln.DotSettings
}

function GetGithubJson([string] $project) {
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    return Invoke-WebRequest -Uri https://api.github.com/repos/OneFrameLink/$project -Headers @{"Accept"="application/vnd.github.v3+json"} | ConvertFrom-Json
}

function SetClassProjectProperties([string] $path, [string] $project, [string] $description,
    [string] $packageProjectUrl, [string] $repositoryUrl) {
    # The xml path.
    $xmlPath = "$path\\$project.csproj"

    # Get the XML from the class project.
    $xml = [xml] (Get-Content $xmlPath)

    # Get the parent node.
    $node = $xml.Project.PropertyGroup

    # Set PropertyGroup.Description
    $newChild = $xml.CreateElement('Description')
    $newChild.set_InnerXml($description)
    $node.AppendChild($newChild)

    # AssemblyName.
    $newChild = $xml.CreateElement('AssemblyName')
    $newChild.set_InnerXml($project)
    $node.AppendChild($newChild)

    # PackageId.
    $newChild = $xml.CreateElement('PackageId')
    $newChild.set_InnerXml($project)
    $node.AppendChild($newChild)

    # PackageProjectUrl.
    $newChild = $xml.CreateElement('PackageProjectUrl')
    $newChild.set_InnerXml($packageProjectUrl)
    $node.AppendChild($newChild)

    # PackageProjectUrl.
    $newChild = $xml.CreateElement('RepositoryUrl')
    $newChild.set_InnerXml($repositoryUrl)
    $node.AppendChild($newChild)

    # TODO: Tags/topics

    # Set PropertyGroup.Version
    $newChild = $xml.CreateElement('Version')
    $newChild.set_InnerXml('1.0.0')
    $node.AppendChild($newChild)

    # Save
    $xml.Save($xmlPath)
}

function CreateClassProject([string] $path, [string] $project) {
    # Create the project.
    dotnet new classlib -f netstandard2.1 -o $path -n $project

    # Get the github JSON.
    $json = GetGithubJson $project

    # Set the properties.
    SetClassProjectProperties $path $project $json.description $json.html_url $json.clone_url
}

function SetTestProjectProperties([string] $path, [string] $testProject, [string] $project) {
    # The xml path.
    $xmlPath = "$path\\$testProject.csproj"

    # Get the XML from the class project.
    $xml = [xml] (Get-Content $xmlPath)

    # Get the parent node.
    $node = $xml.Project.PropertyGroup

    # Remove target framework.
    $node.RemoveChild($node.SelectSingleNode("TargetFramework"))

    # Add TargetFrameworks
    $newChild = $xml.CreateElement('TargetFrameworks')
    $newChild.set_InnerXml('netcoreapp3.1')
    $node.AppendChild($newChild)

    # Set to the project parent.
    $node = $xml.Project

    # Add the reference to the main project.
    $itemGroup = $xml.CreateElement('ItemGroup')
    $projectReference = $xml.CreateElement('ProjectReference')
    $projectReference.SetAttribute('Include', "..\..\src\$project\$project.csproj")
    $itemGroup.AppendChild($projectReference)
    $node.AppendChild($itemGroup)

    # Save
    $xml.Save($xmlPath)
}


function CreateTestProject([string] $path, [string] $testProject, [string] $project) {
    # Create the test project.
    dotnet new xunit -o $path -n $testProject

    # Set the properties
    SetTestProjectProperties $path $testProject $project
}

function UpdateSolution([string] $path, [string] $project) {
    # Get the content as a string.
    $solution = Get-Content $path\\$project.sln

    # Replace everything.
    $solution = $solution.Replace("SOURCE_FOLDER_GUID", [guid]::NewGuid().ToString().ToUpper())
    $solution = $solution.Replace("TEST_FOLDER_GUID", [guid]::NewGuid().ToString().ToUpper())
    $solution = $solution.Replace("SOURCE_PROJECT_GUID", [guid]::NewGuid().ToString().ToUpper())
    $solution = $solution.Replace("TEST_PROJECT_GUID", [guid]::NewGuid().ToString().ToUpper())
    $solution = $solution.Replace("SOLUTION_ITEMS_GUID", [guid]::NewGuid().ToString().ToUpper())
    $solution = $solution.Replace("EXTENSIBILITY_GLOBAL_SECTION_SOLUTION_GUID", [guid]::NewGuid().ToString().ToUpper())
    $solution = $solution.Replace("PROJECT_NAME", $project)

    # Save back.
    Set-Content $path\\$project.sln $solution
}

function CreateProjects([string] $project, [string] $path) {
    # The test project.
    $testProject = "$project.Tests"

    # The source and test paths.
    $srcPath = "$path\src\$project"
    $testPath = "$path\test\$testProject"

    # Create the source and test subdirectories
    New-Item $srcPath -type directory
    New-Item $testPath -type directory

    # Create the class project.
    CreateClassProject $srcPath $project

    # Create the test project
    CreateTestProject $testPath $testProject $project

    # Update the solution.
    UpdateSolution $path $project
}

function CreateSolution([string] $project, [string] $path, [string] $root) {
    Write-Host
    Write-Host "Starting creation of solution"

    # Initialize git.
    InitializeGit $project $path

    # Copy shared out into the root.
    CopyShared $path $project

    # Create the projects.
    CreateProjects $project $path

    explorer .

    Set-Location -Path $root

    Write-Host "Creation of solution complete"
}

function DeleteExisting([string] $project, [string] $path) {
    # Delete the directory if it exists.
    Write-Host "Starting removal of directory $path"
    Remove-Item -LiteralPath $path -Force -Recurse
    Write-Host "Removal of directory $path complete"
    Write-Host
}

function BeginDebug([string] $project, [string] $root, [string] $path) {
    # Write-Host
    Write-Host "Project: $project"
    Write-Host "Root: $root"
    Write-Host "Path: $path"
    Write-Host
}

# The root
$root = (Get-Item -Path ".\" -Verbose).FullName

# The path.
$path = $root + "\" + $project

# Begin debug info.
BeginDebug $project $root $path

# Delete existing.
DeleteExisting $project $path

# Create the solution
CreateSolution $project $path $root

