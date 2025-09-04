# SQLite3.Native

A NuGet package that provides native SQLite3 DLL libraries for Windows platforms (x86, x64, ARM64) designed for use with P/Invoke in C# projects.

![SQLite](https://upload.wikimedia.org/wikipedia/commons/thumb/9/97/Sqlite-square-icon.svg/64px-Sqlite-square-icon.svg.png)

## Overview

This package contains pre-compiled SQLite3 native libraries for Windows that enable C# applications to use SQLite through Platform Invoke (P/Invoke) calls. It's specifically designed to work with [`sqlite-net-static`](https://www.nuget.org/packages/sqlite-net-static/) which provides the C# wrapper and ORM functionality.

## Supported Platforms

- **Windows x64** (`win-x64`)
- **Windows x86** (`win-x86`)
- **Windows ARM64** (`win-arm64`)

## Installation

Install both packages via NuGet Package Manager:

```bash
dotnet add package SQLite3.Native
dotnet add package sqlite-net-static
```

Or add to your project file:

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net6.0</TargetFramework>
  </PropertyGroup>
  
  <ItemGroup>
    <PackageReference Include="sqlite-net-static" Version="1.8.116" />
    <PackageReference Include="SQLite3.Native" Version="3.50.4" />
  </ItemGroup>
</Project>
```

## How It Works

1. **SQLite3.Native** provides the native `sqlite3.dll` files for each supported Windows platform
2. **sqlite-net-static** provides the C# API and P/Invoke declarations to call into the native SQLite library
3. The MSBuild integration automatically copies the correct native DLL to your output directory based on your target platform

## Usage Example

```csharp
using SQLite;

// Create a database connection
var db = new SQLiteConnection("MyDatabase.db");

// Create a table
db.CreateTable<Person>();

// Insert data
db.Insert(new Person { Name = "John", Age = 30 });

// Query data
var people = db.Table<Person>().ToList();

public class Person
{
    [PrimaryKey, AutoIncrement]
    public int Id { get; set; }
    public string Name { get; set; }
    public int Age { get; set; }
}
```

## What's Included

- Native SQLite3 DLL libraries for Windows platforms
- Definition files (`.def`) for each platform
- MSBuild props file for automatic DLL deployment
- Platform-specific runtime targeting

## Version Information

- **Current Version**: 3.50.4
- **SQLite Version**: Based on official SQLite releases
- **License**: MIT

## Requirements

- .NET projects targeting Windows platforms
- Compatible with .NET Framework, .NET Core, and .NET 5+

## Repository

- **Source**: [https://github.com/danny8002/SQlite3.Native](https://github.com/danny8002/SQlite3.Native)
- **Issues**: Report issues on the GitHub repository

## Related Packages

- [`sqlite-net-static`](https://www.nuget.org/packages/sqlite-net-static/) - Required C# SQLite ORM and P/Invoke wrapper
- [`SQLite-net`](https://www.nuget.org/packages/sqlite-net-pcl/) - Alternative PCL version

## License

This package is released under the MIT License.
