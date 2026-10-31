-- Persistent server-side employee progression; rewards only after verified bank payment.
local ranks = {{1,'Trainee Gardener'},{3,'Groundskeeper'},{5,'Landscaper'},{8,'Senior Landscaper'},{12,'Forestry Specialist'},{20,'Master Landscaper'}}
local function rankFor(level)
    local name=ranks[1][2]
    for _,r in ipairs(ranks) do if level>=r[1] then name=r[2] end end
    return name
end
local function levelFor(xp)
    return math.min(100,math.floor(math.sqrt(math.max(0,xp)/100))+1)
end
local function playerIdentity(src)
    local player=exports.qbx_core:GetPlayer(src)
    if not player or not player.PlayerData then return nil end
    local data=player.PlayerData
    local info=data.charinfo or {}
    local name=((info.firstname or '')..' '..(info.lastname or '')):gsub('^%s+',''):gsub('%s+$','')
    return data.citizenid, name~='' and name or ('Employee '..tostring(src))
end
local function ensureRow(cid,name)
    MySQL.insert.await('INSERT INTO wonkys_landscaping_employees (citizenid, employee_name) VALUES (?, ?) ON DUPLICATE KEY UPDATE employee_name = VALUES(employee_name)',{cid,name})
end
-- Called only from the contract server after bank payment succeeds.
function LandscapingAwardProgress(src,paidAmount)
    local cid,name=playerIdentity(src)
    if not cid then return false end
    local xp=math.max(25,math.floor(tonumber(paidAmount)*0.2))
    local ok,err=pcall(function()
        ensureRow(cid,name)
        MySQL.update.await('UPDATE wonkys_landscaping_employees SET jobs_completed=jobs_completed+1, total_xp=total_xp+?, lifetime_earnings=lifetime_earnings+?, weekly_jobs=weekly_jobs+1, weekly_xp=weekly_xp+?, last_completed=NOW() WHERE citizenid=?',{xp,paidAmount,xp,cid})
    end)
    if not ok then print('[Wonkys_Landscaping] Progress database error: '..tostring(err)) end
    return ok
end
-- v0.26.5: Forestry XP only after the server confirms a real tree pickup.
-- Uses the existing employee table, level formula, and leaderboard.
function LandscapingAwardForestryXP(src,kind)
    local xpByKind={logs=Config.Logging.xpTimberPickup or 30,leaves=Config.Logging.xpLeafPickup or 15}
    local xp=xpByKind[kind]
    if not xp or xp<=0 then return false end
    local cid,name=playerIdentity(src)
    if not cid then return false end
    local ok,err=pcall(function()
        ensureRow(cid,name)
        MySQL.update.await('UPDATE wonkys_landscaping_employees SET total_xp=total_xp+?, weekly_xp=weekly_xp+? WHERE citizenid=?',{xp,xp,cid})
    end)
    if not ok then
        print('[Wonkys_Landscaping] Forestry XP database error: '..tostring(err))
        return false
    end
    TriggerClientEvent('wonkys_landscaping:forestry:xp',src,xp,kind)
    return true
end

lib.callback.register('wonkys_landscaping:progression:dashboard',function(src)
    if not LandscapingOnShift(src) then return nil end
    local cid,name=playerIdentity(src)
    if not cid then return nil end
    local ok,result=pcall(function()
        ensureRow(cid,name)
        local own=MySQL.single.await('SELECT jobs_completed,total_xp,lifetime_earnings,weekly_jobs,weekly_xp FROM wonkys_landscaping_employees WHERE citizenid=?',{cid})
        local leaders=MySQL.query.await('SELECT employee_name,jobs_completed,total_xp FROM wonkys_landscaping_employees ORDER BY jobs_completed DESC,total_xp DESC LIMIT 10') or {}
        local weekly=MySQL.query.await('SELECT employee_name,weekly_jobs AS jobs_completed,weekly_xp AS total_xp FROM wonkys_landscaping_employees WHERE weekly_jobs>0 ORDER BY weekly_jobs DESC,weekly_xp DESC LIMIT 10') or {}
        local xp=tonumber(own.total_xp) or 0
        local level=levelFor(xp)
        return {self={name=name,jobs=own.jobs_completed,xp=xp,level=level,rank=rankFor(level),earnings=own.lifetime_earnings,weeklyJobs=own.weekly_jobs,nextLevelXp=level*level*100},leaders=leaders,weekly=weekly}
    end)
    if not ok then print('[Wonkys_Landscaping] Progression read error: '..tostring(result));return nil end
    return result
end)
