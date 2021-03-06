
function to_html_md(name, screencapture_file, width)
    if screencapture_file == nothing
        return "" # aww, no screencapture :(
    elseif endswith(screencapture_file, ".webm")
        return """<video  width="$width" autoplay loop><source src="../../media/$(screencapture_file)">Your browser does not support the video tag.</video>"""
    else # should be an image
        return """<img src="../../media/$(screencapture_file)"
            alt="$(name)" style="width: $(width)px;"/>
        """
    end
end

function file2doc(name, source_path, doc_md_io, screencapture_file)
    if screencapture_file == nothing
        preview = "" # aww, no screencapture :(
    elseif endswith(screencapture_file, ".webm")
        preview = """<video  width="600" autoplay loop><source src="../../media/$(screencapture_file)"> Your browser does not support the video tag. </video>"""
    else # should be an image
        preview = "![$(name)](../../media/$(screencapture_file))"
    end

    # declutter the source a bit
    source_code = open(source_path) do io
        sprint() do str_io
            needs_end = false
            println(source_path)
            for line in readlines(io)
                line = chomp(line)
                if startswith(line, "if !isdefined(:runtests)")
                    needs_end = true
                    continue
                end
                if startswith(line, "else") && needs_end
                    continue
                end
                if startswith(line, "end") && needs_end
                    needs_end = false
                    continue
                end
                if (
                        startswith(line, "const record_interactive = true") ||
                        startswith(line, "const static_example = true")
                    )
                    continue
                end
                if needs_end # we are in a !isdefined(:runtests) block
                    # we should remove the tabs
                    if beginswith(line, " "^4)
                        line = line[5:end]
                    elseif beginswith(line, "\t")
                        line = line[2:end]
                    end
                end
                println(str_io, line)
            end

        end
    end
    print(doc_md_io,
"""
# $name

$(preview)

```Julia
$(source_code)
```

"""
    )
end
function remove_root(root, path)
    rootsplit = split(root, Base.Filesystem.path_separator)
    pathsplit = split(path, Base.Filesystem.path_separator)

    path = joinpath(pathsplit[length(rootsplit):end]...)
    path
end
function file2doc(sourcepath, doc_md_io)
    filename = basename(sourcepath)[1:end-3] # remove .jl
    headlines = split(filename, "_")
    name = join(map(x->ucfirst(x), headlines), " ")
    # get matching screen record
    println("filename ", filename)
    screencapture = filter(readdir(screencapture_root)) do file
        fname, ext = splitext(file)
        fname == filename
    end
    if isempty(screencapture)
        #no record found for filename, so it's nothing
        screencapture = nothing
    elseif length(screencapture) == 1
        screencapture = screencapture[1]
    elseif length(screencapture) > 1
       warn("found duplicate screen recordings for: $filename")
    end
    println("screencapture ", screencapture)
    file2doc(name, sourcepath, doc_md_io, screencapture)
end

#const doc_root = "C:\\Users\\Sim\\GLVisualize\\docs"
const doc_root = Pkg.dir("GLVisualizeDocs", "docs")
const screencapture_root = joinpath(doc_root, "media")
const source_root = Pkg.dir("GLVisualize", "examples")

function make_docs(path::AbstractString)
    println(path)
    if isdir(path) # we should be on the level of jl files. eg. in dir particles with all particle examples
        name = basename(path)
        println("name ", name)
        # for one folder we only create one md, because mcdocs doesn't allow to deep hierarchies
        dir_level = remove_root(source_root, path)
        dir_level, _ = splitdir(dir_level) # remove last folder
        doc = joinpath(doc_root, dir_level, "$(name).md")
        open(doc, "w") do io
            for file in readdir(path) # read all files and concat the docs for that one
                file2doc(joinpath(path, file), io)
            end
        end
    elseif isfile(path) && endswith(path, ".jl")
        println("whaaat???")
    end
    nothing # ignore other cases
end
function make_docs(directories::Vector)
    for dir in directories
        println("dir ", dir)
        make_docs(joinpath(source_root, dir))
    end
end
function make_docs(directories::Vector, io)
    for file in directories
        file2doc(file, io)
    end
end

#make_docs(readdir(source_root))


open(joinpath(doc_root, "index.md"), "w") do io
    names = filter(x->endswith(x, ".webm"), readdir(screencapture_root))
println(io, """
## Welcome the Documentation of GLVisualize

GLVisualize is an interactive 3D visualization library written in Julia and modern OpenGL.
Its focus is on scientific visualizations but is not restricted to it.
There are lots of 2D and 3D visualization types like particles, surfaces, meshes, sprites, lines and text.
It uses [Reactive](https://github.com/JuliaLang/Reactive.jl) to offer an easy way of animating your data.
It also offers very basic GUI elements like slider and buttons.

Please check out the examples to see what GLVisualize is capable of.

""")
    for x=1:4
        for y=1:4
            path = names[sub2ind((4,4), x, y)]
            html = to_html_md(splitext(path)[1], path, 200)
            print(io, html)
        end
    end
end

open(joinpath(doc_root, "performance.md"), "w") do io
println(io, """# Performance tips for GLVisualize

GLVisualize doesn't optimize drawing many RenderObjects objects well yet.
Better OpenGL draw call optimization would be needed for that.
So if you need to draw many objects, make sure that you use the particle system or merge meshes whenever possible.

For animations, make sure to pass a static boundingbox via the keyword arguments.

E.g:
```Julia
visualize(x, boundingbox = nothing) # Or AABB{Float32}(Vec3f0(0),Vec3f0(0))
```
Otherwise the boundinbox will be calculated every time the signal updates which can be very expensive.


If you want to find out a bit more about the genral performance of GLVisualize, you can
read this [blog post](http://randomfantasies.com/2015/05/glvisualize-benchmark/).
It's a bit outdated but should still be accurate.
"""
)
end
open(joinpath(doc_root, "known_issues.md"), "w") do io
println(io, """# Known Issues
Please refer to the [Github issues](https://github.com/JuliaGL/GLVisualize.jl/issues)

* Boundingboxes are not always correct
* On Mac OS, you need to make sure that Homebrew.jl works correctly, which was not the case on some tested machines (needed to checkout master and then rebuild)
* GLFW needs cmake and xorg-dev libglu1-mesa-dev on linux (can be installed via sudo apt-get install xorg-dev libglu1-mesa-dev).
* VideoIO and FreeType seem to be also problematic on some platforms. There isn't a fix for all situations. If these package fail, try Pk.update();Pkg.build("FailedPackage"). If this still fails, report an issue on Github!
""")
end
include("create_api.jl")

write_api(joinpath(doc_root, "api.md"))
