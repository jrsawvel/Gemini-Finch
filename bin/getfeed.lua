#!/usr/local/bin/lua


package.path = package.path .. ';/home/gemini/finch/GeminiFinch/lib/?.lua'

local feedparser  = require "feedparser"
local rex = require "rex_pcre"


local utils  = require "utils"
local page   = require "page"
local config = require "config"
local finch  = require "finch"


local homepage_url_list = {}

local urls = finch.read_file(config.get_value_for("feeds_urls_file"))

local url_ctr

local working_feed_ctr = 1

for url_ctr=1, #urls do

    local url = urls[url_ctr]
    print("Processing URL: " .. url)

    -- local body, code, headers, status = utils.fetch_url(url)
    local body, code, headers, status = utils.fetch_url(url)

  if code > 20 then
        print("Error: Could not fetch " .. url .. ". Status: " .. status .. ". Code: " .. code .. ". Headers: " .. headers)
  else

    body = utils.trim_spaces(body)

    if body == nil or string.len(body) < 1 then
        print("Error: Nothing returned to parse for URL " .. url)
    else
        local parsed, errmsg = feedparser.parse(body, url)

        if parsed == nil then
            print("Error: " .. errmsg .. " for URL " .. url)
            print("Determining whether feed is a different format.")
            if url:match("rss3.txt") or headers:match("text/plain") then
                local blocks = utils.split(body, "\n\n")
                local feed = {}
                local items_array = {}

                for i=1,#blocks do
                    local tmp_hash = {}
                    for n, v in rex.gmatch(blocks[i], "(\\w+): (.*)", "", nil) do
                        tmp_hash[n] = v
                    end
                    if i > 1 then
                        table.insert(items_array, tmp_hash)
                    else
                        feed.site = tmp_hash
                    end
                end

                feed.items = items_array

                page.set_template_name("rss3feed")
                page.set_template_variable("feedurl", url)
                page.set_template_variable("feedtitle", feed.site.title)
                page.set_template_variable("feedhomepage", feed.site.link)
                page.set_template_variable("feedsubtitleexists", true)
                page.set_template_variable("feedsubtitle", feed.site.description)
                page.set_template_variable("feedupdatedexists", true)
                page.set_template_variable("feedupdated", feed.site.modified)
                page.set_template_variable("itemsloop", feed.items)

                local gmi_output = page.get_output(feed.site.title) 

                local feed_domain, feed_gmi_file = finch.create_feed_gmi_file(url, gmi_output, feed.site.link)

                homepage_url_list[working_feed_ctr] = {
                    feedgmifile  =  feed_gmi_file, 
                    feeddomain    =  feed_domain,
                    feedtitle     =  feed.site.title
                }
                working_feed_ctr = working_feed_ctr + 1
                page.reset()
            else
                print("Failed to parse feed for URL " .. url)
            end
        else
            local a_entries = parsed.entries -- rss/atom items

            page.set_template_name("feed")
            page.set_template_variable("feedurl", url)
            page.set_template_variable("feedtitle", parsed.feed.title)

            for i=1, #parsed.feed.links do
                if parsed.feed.links[i].rel == "alternate" then
                    page.set_template_variable("feedhomepage", parsed.feed.links[i].href)
                end
            end

            if parsed.feed.subtitle ~= nil then
                page.set_template_variable("feedsubtitleexists", true)
                page.set_template_variable("feedsubtitle", parsed.feed.subtitle) 
            else
                page.set_template_variable("feedsubtitleexists", false)
            end

            if parsed.feed.updated ~= nil then
                page.set_template_variable("feedupdatedexists", true)
                page.set_template_variable("feedupdated", parsed.feed.updated) 
            else
                page.set_template_variable("feedupdatedexists", false)
            end

            local feed_items_array = {}

            for i=1,#a_entries do
                local item_hash = {}

                local MAX_SUMMARY_LEN = 300 -- characters

                local title   = a_entries[i].title
                local summary = a_entries[i].summary

                if summary == nil then 
                    summary = a_entries[i].content
                end

                local updated = a_entries[i].updated
                local link    = a_entries[i].links[1].href
                local brief_summary = nil

                if summary ~= nil and string.len(summary) > MAX_SUMMARY_LEN then
                    brief_summary = utils.remove_html(summary)
                    brief_summary = string.sub(brief_summary, 1, MAX_SUMMARY_LEN)
                end

                if title ~= nil and summary ~= nil then
                    if title == summary then
                        -- it's probably a note type of post with the title copied from the description.
                        -- this could have been stored in the rss file without a title.
                        -- print only the summary.
                        item_hash.itemsummaryexists = true
                        -- item_hash.itemsummary = summary
                        item_hash.itemsummary = utils.html_to_gmi(summary)
                    else
                        item_hash.itemsummaryexists = true
                        -- item_hash.itemsummary = summary
                        item_hash.itemsummary = utils.html_to_gmi(summary)
                        item_hash.itemtitleexists = true
                        item_hash.itemtitle = title
                    end
                elseif title ~= nil then
                    item_hash.itemtitleexists = true
                    item_hash.itemtitle = title
                elseif summary ~= nil then
                    item_hash.itemsummaryexists = true
                    -- item_hash.itemsummary = summary
                    item_hash.itemsummary = utils.html_to_gmi(summary)
                end

                if brief_summary ~= nil then
                    -- html_output = html_output .. '<p>\n' .. brief_summary .. '</p>\n'
                end

                item_hash.itemlink = link
                item_hash.itemupdated = updated

                feed_items_array[i] = item_hash
            end

            page.set_template_variable("itemsloop", feed_items_array)           

            local gmi_output = page.get_output(parsed.feed.title) 

            local feed_domain, feed_gmi_file = finch.create_feed_gmi_file(url, gmi_output, parsed.feed.links[1].href)

            if parsed.feed.title == nil or string.len(parsed.feed.title) < 3 then
                parsed.feed.title = parsed.feed.links[1].href
            end

            homepage_url_list[working_feed_ctr] = {
                feedgmifile   =  feed_gmi_file, 
                feeddomain    =  feed_domain,
                feedtitle     =  parsed.feed.title
            }
 
            working_feed_ctr = working_feed_ctr + 1

            page.reset()
        end
    end
  end
end -- for loop


page.reset()

page.set_template_name("homepage")

page.set_template_variable("feedpagesloop", homepage_url_list)

local homepage_gmi_output = page.get_output("Finch Homepage")

finch.create_homepage_gmi_file(homepage_gmi_output)


