---@class Ghsigns.Gh
---@field bin string
---@field private fields string
local Gh = {}

---@class Ghsigns.Pr
---@field additions integer
---@field assignees table
---@field author table
---@field autoMergeRequest? boolean
---@field baseRefName string
---@field baseRefOid string
---@field body string
---@field changedFiles integer
---@field closed boolean
---@field closedAt? string
---@field closingIssuesReferences table
---@field comments table
---@field commits table
---@field createdAt string
---@field deletions integer
---@field files table
---@field fullDatabaseId string
---@field headRefName string
---@field headRefOid string
---@field headRepository table
---@field headRepositoryOwner table
---@field id string
---@field isCrossRepository boolean
---@field isDraft boolean
---@field labels table
---@field latestReviews table
---@field maintainerCanModify boolean
---@field mergeCommit? string
---@field mergeStateStatus string
---@field mergeable string
---@field mergedAt? string
---@field mergedBy? string
---@field milestone? string
---@field number integer
---@field potentialMergeCommit? string
---@field projectCards? string
---@field projectItems table
---@field reactionGroups table
---@field reviewDecision string
---@field reviewRequests table
---@field reviews table
---@field state string
---@field statusCheckRollup table
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
      "assignees",
      "author",
      "autoMergeRequest",
      "baseRefName",
      "baseRefOid",
      "body",
      "changedFiles",
      "closed",
      "closedAt",
      "closingIssuesReferences",
      "comments",
      "commits",
      "createdAt",
      "deletions",
      "files",
      "fullDatabaseId",
      "headRefName",
      "headRefOid",
      "headRepository",
      "headRepositoryOwner",
      "id",
      "isCrossRepository",
      "isDraft",
      "labels",
      "latestReviews",
      "maintainerCanModify",
      "mergeCommit",
      "mergeStateStatus",
      "mergeable",
      "mergedAt",
      "mergedBy",
      "milestone",
      "number",
      "potentialMergeCommit",
      "projectCards",
      "projectItems",
      "reactionGroups",
      "reviewDecision",
      "reviewRequests",
      "reviews",
      "state",
      "statusCheckRollup",
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

return Gh
