# JuliaPkgDb

Julia's METADATA package registry stuffed into a SQLite database.

## Installation

Building the database requires Julia 0.4 or higher with the SQLite package.
To install the SQLite package, simply execute

```julia
Pkg.add("SQLite")
```

at the Julia REPL.
Once that's installed, you're ready to make a database.
Navigate to the directory where this project lives and run

```bash
julia makedb.jl
```

This creates the file `julia_packages.db` in the same directory.

## Schema

The database, `julia_packages.db` contains two tables: `Packages` and `Versions`.
All fields in both tables are `varchar`.

### Packages

| Column   | Description      |
| -------- | ---------------- |
| `Name`   | Package name     |
| `URL`    | Repository URL   |
| `Owner`  | Repository owner |

This table has one row per package.
The `Name` and `URL` fields will never be null but `Owner` may be if the package
repository's owner cannot be determined from the URL.
Currently owners are only detected for GitHub repositories.

### Versions

| Column       | Description  |
| ------------ | ------------ |
| `Package`    | Package name |
| `Version`    | Release version number |
| `SHA1`       | SHA-1 of the commit for the tagged release |
| `Dependency` | Name of the package on which `Package` depends |
| `LowerBound` | Lower bound on the required version of `Dependency` |
| `UpperBound` | Upper bound on the required version of `Dependency` |
| `Platform`   | If the requirement is platform-specific, which platform |

This table has one row per package, version, and dependency.
The dependency-related fields may be null but the package name, version number,
and commit SHA will not be.

## Example usage

Say you want to find all package versions of JuliaStats packages that depend on
the `DataArrays` package.

```sql
select distinct p.Name, v.Version
from Packages as p
inner join Versions as v
on p.Name = v.Package
where p.Owner = "JuliaStats"
    and v.Dependency = "DataArrays";
```

You can run that in the SQLite REPL, from Julia using `SQLite.execute!`, or
however you want!
