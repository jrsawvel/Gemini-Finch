
local M = {}

local rex   = require "rex_pcre"

local config = require "config"



function M.create_homepage_gmi_file(gmi)

    local doc_root = config.get_value_for("default_doc_root")

    local gmi_filename = doc_root .. "/index.gmi"

    local f = io.open(gmi_filename, "w")
    if f == nil then
        error("Could create output file for write for " .. gmi_filename .. ".")
    else
        f:write(gmi)
        f:close()
    end
end


function M.create_feed_gmi_file(feedurl, gmi, homepageurl)

    homepageurl = feedurl -- jrs 08Mar2019 addition

    if homepageurl ~= nil then
        homepageurl =  rex.gsub(homepageurl, "[^a-zA-Z0-9]","")
    end

    local protocol, domain = rex.match(feedurl, "(\\w+://)([.A-Za-z0-9\\-]+)/", 1)

    local d = rex.gsub(domain, "\\.", "", nil, "is")

    local doc_root = config.get_value_for("default_doc_root")

    local gmi_filename

    local gmi_page

    if homepageurl ~= nil then
        gmi_page = homepageurl .. "feed.gmi"
        gmi_filename = doc_root .. "/" .. gmi_page
    else
        gmi_page = d .. "feed.gmi"
        gmi_filename = doc_root .. "/" .. gmi_page
    end

    local f = io.open(gmi_filename, "w")
    if f == nil then
        error("Could create output file for write for " .. gmi_filename .. ".")
    else
        f:write(gmi)
        f:close()
    end

    return domain, gmi_page
end


function M.read_file(filename)
    local f = io.open(filename, "r")
    if f == nil then
        error("Could not open " .. filename .. " for reading.")
    end

    local urls = {}

    local i = 1
 
    for line in f:lines() do
        if string.len(line) > 12 then
            urls[i] = line
            i = i + 1
        end
    end

    f:close()

    return urls
end


return M

