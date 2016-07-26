using SQLite

loc = dirname(@__FILE__)

if isfile(joinpath(loc, "julia_packages.db"))
    rm(joinpath(loc, "julia_packages.db"))
end

db = SQLite.DB(joinpath(loc, "julia_packages.db"))

SQLite.execute!(db, """
    create table if not exists [Packages] (
        [Name] varchar(50) not null,
        [URL] varchar(200) not null,
        [Owner] varchar(100) default null
    );
""")

SQLite.execute!(db, """
    create table if not exists [Versions] (
        [Package] varchar(50) not null,
        [Version] varchar(15) not null,
        [SHA1] varchar(50) not null,
        [Dependency] varchar(50) default null,
        [LowerBound] varchar(15) default null,
        [UpperBound] varchar(15) default null,
        [Platform] varchar(7) default null
    );
""")

pkg_insert = SQLite.Stmt(db, "insert into Packages values (?1, ?2, ?3);")
vers_insert = SQLite.Stmt(db, "insert into Versions values (?1, ?2, ?3, ?4, ?5, ?6, ?7);")

if isdir(joinpath(loc, "METADATA.jl"))
    rm(joinpath(loc, "METADATA.jl"), recursive=true)
end

cd(loc) do
    run(`git clone -q --depth 1 -b metadata-v2 https://github.com/JuliaLang/METADATA.jl.git`)
end

const GHURL = r"^(?:git@|git://|https://(?:[\w\.\+\-]+@)?)github.com[:/](([^/].+)/(.+?))(?:\.git)?$"i

for pkg in readdir(joinpath(loc, "METADATA.jl"))
    pkgdir = joinpath(loc, "METADATA.jl", pkg)

    (!isdir(pkgdir) || pkg == ".git" || pkg == ".test") && continue

    if isfile(joinpath(pkgdir, "url"))
        url = readchomp(joinpath(pkgdir, "url"))
    else
        warn("$pkg will be omitted from the database: does not have a URL")
        continue
    end

    if !isdir(joinpath(pkgdir, "versions"))
        warn("$pkg will be omitted from the database: no available versions")
        continue
    end

    SQLite.bind!(pkg_insert, 1, pkg)
    SQLite.bind!(pkg_insert, 2, url)
    SQLite.bind!(pkg_insert, 3, ismatch(GHURL, url) ? match(GHURL, url).captures[2] : SQLite.NULL)
    SQLite.execute!(pkg_insert)

    for ver in readdir(joinpath(pkgdir, "versions"))
        verdir = joinpath(pkgdir, "versions", ver)

        if isfile(joinpath(verdir, "sha1"))
            sha = readchomp(joinpath(verdir, "sha1"))
        else
            warn("$pkg version $ver will be omitted: no corresponding SHA-1")
            continue
        end

        for (i, val) in zip(1:3, (pkg, ver, sha))
            SQLite.bind!(vers_insert, i, val)
        end

        if isfile(joinpath(verdir, "requires"))
            lines = map(chomp, readlines(joinpath(verdir, "requires")))
            filter!(s -> !isempty(s) && !all(isspace, s), lines)

            for req in lines
                m = match(r"^(@\w+\s+)?(\w+)(\s+[\d.-]+)?(\s+[\d.-]+)?", req)
                m === nothing && continue

                plt, dep, lb, ub = m.captures

                SQLite.bind!(vers_insert, 4, dep)
                SQLite.bind!(vers_insert, 5, lb === nothing ? SQLite.NULL : lstrip(lb))
                SQLite.bind!(vers_insert, 6, ub === nothing ? SQLite.NULL : lstrip(ub))
                SQLite.bind!(vers_insert, 7, plt === nothing ? SQLite.NULL : rstrip(plt)[2:end])

                SQLite.execute!(vers_insert)
            end
        else
            for i = 4:6
                SQLite.bind!(vers_insert, i, SQLite.NULL)
            end

            SQLite.execute!(vers_insert)
        end
    end
end

for tbl in (:Packages, :Versions)
    @assert size(SQLite.query(db, "select * from $tbl limit 1;"), 1) > 0
end

rm(joinpath(loc, "METADATA.jl"), recursive=true)
