function many_columns(conf)
    local background_image = conf.image

    local outerColumns = pandoc.Div({})
    outerColumns.classes:insert("columns")
    if conf.dark then
        outerColumns.classes:insert("has-dark-background")
    end

    for i, v in ipairs(conf.columns) do
        local innerColumn = pandoc.Div(v)
        innerColumn.classes:insert("column")
        innerColumn.attributes.width = conf.widths[i];
        outerColumns.content:insert(innerColumn)
    end

    local header_block = pandoc.Header(2, "")

    header_block.attr.attributes["background-image"] = "_extensions/positslides/assets/backgrounds/" .. background_image .. ".png"
    header_block.attr.attributes["background-size"] = "contain"

    local new_blocks = pandoc.List({})
    new_blocks:insert(header_block)
    new_blocks:insert(outerColumns)

    return new_blocks
end

local slide_styles = {}

function blank_column(_content)
    return { pandoc.RawBlock("html", "&nbsp;") }
end

function content_column(c)
    local result = pandoc.List({})
    local title = pandoc.utils.stringify(c[1].content)
    result:insert(pandoc.RawBlock("html", "<h2>" .. title .. "</h2>"))
    result:extend(c)
    result:remove(2)
    return result
end

local blank = pandoc.RawBlock("html", "&nbsp;")
for i, v in ipairs({
    { image = "30-70-dark",
      widths = { "35%", "65%" },
      columns = { blank_column, content_column },
    },
    { image = "30-70-light",
      widths = { "35%", "65%" },
      columns = { blank_column, content_column },
    },
    { image = "dark-section",
      dark = true,
      widths = { "35%", "65%" },
      columns = { blank_column, content_column },
    },
    { image = "dark-section-2",
      dark = true,
      widths = { "55%", "45%" },
      columns = { blank_column, content_column },
    },
    { image = "dark-section-3",
      dark = true,
      widths = { "45%", "55%" },
      columns = { function (content) 
        local result = content_column(content)
        result:insert(1, pandoc.RawBlock("html", "<br>"))
        return result
     end, blank_column },
    },
    { image = "toc-dark",
      dark = true,
      widths = { "100%" },
      columns = { content_column },
    },
    { image = "toc-light",
      widths = { "100%" },
      columns = { content_column },
    }})     do
    slide_styles[v.image] = (function(v)
        setmetatable(v.columns, getmetatable(pandoc.List({})))
        return function(content)
            return many_columns({
                dark = v.dark,
                image = v.image, 
                widths = v.widths,
                columns = v.columns:map(function(col) return col(content) end)
            })
        end
    end)(v)
end

-- TODO dark-section needs light text

function mysplit (inputstr, pattern)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    local matched = false
    for str in string.gmatch(inputstr, pattern) do
        matched = true
        table.insert(t, str)
    end
    if not matched then
        return { inputstr }
    end
    return t
end

function process_header_attributes(header)
    local title = pandoc.utils.stringify(header.content)
    local match = title:match(" {.*}$")
    if match == nil then return header end
    local attribute = match:sub(3, -2)
    header.content = pandoc.Plain({ pandoc.Str(title:gsub(" {.*}$", "")) })
    for i, v in pairs(mysplit(attribute, " ")) do
        if v:sub(1, 1) == "#" then
            header.attr.identifier = v:sub(2)
        elseif v:sub(1, 1) == "." then
            table.insert(header.attr.classes, v:sub(2))
        else
            local key, value = i:match("(.*)=(.*)")
            if key and value then
                header.attr.attributes[key] = value
            else
                header.attr.attributes[i] = true
            end
        end
    end
    return header
end


function process(content, classes)
    if classes == nil then
        classes = content[1].attr.classes
    end
    for i, v in ipairs(classes) do
        if slide_styles[v] then
            return slide_styles[v](content)
        end
    end
    return content
end

function Pandoc(doc)
    quarto.doc.add_html_dependency({
        name = 'posit_slides',
        scripts = { 'assets/posit-slides.js' },
    })

    local new_blocks = pandoc.List({})
    local sections = pandoc.utils.make_sections(false, nil, doc.blocks)

    for i, div in ipairs(sections) do
        if div.t ~= "Div" then
            new_blocks:insert(div)
        else
            if div.content[1].t == "Header" then
                div.content[1] = process_header_attributes(div.content[1])
            end
            new_blocks:extend(process(div.content))
        end
    end
    doc.blocks = new_blocks
    return doc
end