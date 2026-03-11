---@class Ghsigns.Autolink
---@field key_prefix string   -- e.g., "HOGE-"
---@field url_template string -- e.g., "https://jira.example.com/browse/HOGE-<num>"
---@field is_alphanumeric? boolean

---@class Ghsigns.Gh
---@field bin string
---@field private fields string
local Gh = {}

---@class Ghsigns.Pr
---@field additions integer
---@field author table
---@field baseRefName string
---@field body string
---@field changedFiles integer
---@field commits table
---@field createdAt string
---@field deletions integer
---@field headRefName string
---@field isDraft boolean
---@field labels table
---@field mergeable string
---@field mergedAt? string
---@field number integer
---@field reviewDecision string
---@field state string
---@field title string
---@field updatedAt string
---@field url string

---@param bin? string
---@return Ghsigns.Gh
Gh.new = function(bin)
  return setmetatable({
    bin = bin or "gh",
    fields = table.concat({
      "additions",
      "author",
      "baseRefName",
      "body",
      "changedFiles",
      "commits",
      "createdAt",
      "deletions",
      "headRefName",
      "isDraft",
      "labels",
      "mergeable",
      "mergedAt",
      "number",
      "reviewDecision",
      "state",
      "title",
      "updatedAt",
      "url",
    }, ","),
  }, { __index = Gh })
end

---@return boolean
function Gh:is_callable()
  local ok = pcall(vim.system, { self.bin, "--version" })
  return ok
end

---@async
---@param root string
---@return string? err
---@return Ghsigns.Pr? pr
function Gh:fetch_pr(root)
  vim.notify("gsigns: Fetching PR info...", vim.log.levels.DEBUG)
  local async = require "gitsigns.async"
  ---@type async fun(cmd: string[], opts?: vim.SystemOpts): vim.SystemCompleted
  local asystem = async.wrap(3, vim.system)
  local result = asystem({ self.bin, "pr", "view", "--json", self.fields }, { cwd = root })
  if result.code ~= 0 then
    return result.stderr
  end
  local ok, pr = pcall(vim.json.decode, result.stdout, { luanil = { object = true } })
  if not ok then
    return "Failed to decode gh pr view output"
  end
  return nil, pr
end

---@async
---@param root string
---@return string? err
---@return Ghsigns.Autolink[]? autolinks
function Gh:fetch_autolinks(root)
  local async = require "gitsigns.async"
  ---@type async fun(cmd: string[], opts?: vim.SystemOpts): vim.SystemCompleted
  local asystem = async.wrap(3, vim.system)
  -- Determine owner/repo/hostname from the git remote
  local remote_result = asystem({ self.bin, "repo", "view", "--json", "owner,name,url" }, { cwd = root })
  if remote_result.code ~= 0 then
    return remote_result.stderr
  end
  local ok_repo, repo_info = pcall(vim.json.decode, remote_result.stdout, { luanil = { object = true } })
  if not ok_repo or not repo_info then
    return "Failed to decode repo info"
  end
  local owner = repo_info.owner and repo_info.owner.login or repo_info.owner
  local name = repo_info.name
  if not owner or not name then
    return "Failed to determine owner/repo"
  end
  local hostname = repo_info.url and repo_info.url:match "https://([^/]+)/"
  local api_cmd = { self.bin, "api", "repos/" .. owner .. "/" .. name .. "/autolinks" }
  if hostname and hostname ~= "github.com" then
    table.insert(api_cmd, "--hostname")
    table.insert(api_cmd, hostname)
  end
  local result = asystem(api_cmd, { cwd = root })
  if result.code ~= 0 then
    return result.stderr
  end
  local ok, data = pcall(vim.json.decode, result.stdout, { luanil = { object = true } })
  if not ok then
    return "Failed to decode autolinks response"
  end
  ---@type Ghsigns.Autolink[]
  local autolinks = {}
  if type(data) == "table" then
    for _, item in ipairs(data) do
      table.insert(autolinks, {
        key_prefix = item.key_prefix,
        url_template = item.url_template,
        is_alphanumeric = item.is_alphanumeric,
      })
    end
  end
  return nil, autolinks
end

return Gh
