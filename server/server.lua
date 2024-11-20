-----------------For support, scripts, and more----------------
--------------- https://discord.gg/wasabiscripts  -------------
---------------------------------------------------------------
local loaded, users, jobs, empty = false, {}, {}, {}

--Threads
CreateThread(function()
    MySQL.ready(function()
        MySQL.Async.fetchAll('SELECT identifier, firstname, lastname FROM users', {}, function(result)
            if result then
                for _, v in pairs(result) do
                    if v.lastname then
                        users[v.identifier] = v.firstname..' '..v.lastname
                    elseif v.firstname then
                        users[v.identifier] = v.firstname
                    end
                end
            end
        end)
        Wait(100)
        MySQL.Async.fetchAll('SELECT name, label FROM jobs', {}, function(result)
            if result then
                for _,v in pairs(result) do
                    jobs[v.name] = {label = v.label, grades = {}}
                end
            end
        end)
        Wait(100)
        MySQL.Async.fetchAll('SELECT job_name, grade, label, salary FROM job_grades', {}, function(result)
            if result then
                for _,v in pairs(result) do
                    if jobs[v.job_name] then
                        jobs[v.job_name].grades[v.grade] = {label = v.label, salary = v.salary}
                    end
                end
            end
        end)
    end)
    loaded = true
end)

if Config.bossMenus.enabled then
    CreateThread(function()
        while ESX == nil do Wait() end
        for i=1, #Config.bossMenus.locations do
            TriggerEvent('esx_society:registerSociety', Config.bossMenus.locations[i].job, Config.bossMenus.locations[i].label, 'society_'..Config.bossMenus.locations[i].job, 'society_'..Config.bossMenus.locations[i].job, 'society_'..Config.bossMenus.locations[i].job, {type = 'public'})
        end
    end)
end

-- Local functions
local jobData
local function getPlayerJobs(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    MySQL.Async.fetchAll('SELECT job, grade FROM wasabi_multijob WHERE identifier = @identifier', {
        ['@identifier'] = xPlayer.identifier,
    }, function(result)
        jobData = {}
        if result[1] then
            for i=1, #result do
                if jobs[result[i].job] and jobs[result[i].job].grades[result[i].grade] then
                    jobData[#jobData + 1] = {job = result[i].job, grade = result[i].grade}
                else
                    MySQL.Async.execute('DELETE FROM wasabi_multijob WHERE identifier = @identifier AND job = @job AND grade = @grade', {
                        ["@identifier"] = xPlayer.identifier,
                        ["@job"] = result[i].job,
                        ["@grade"] = result[i].grade
                    })
                end
            end
        end
    end)
end

local function giveOfflineBonus(identifier, amount)
    MySQL.single('SELECT accounts FROM users WHERE identifier = ?', {identifier}, function(result)
        if result then
            local accounts = json.decode(result.accounts)
            accounts.bank = accounts.bank + amount
            MySQL.update('UPDATE users SET accounts = ? WHERE identifier = ?', {json.encode(accounts), identifier}, function(affectedRows) end)
        end
    end)
    return true
end

local function addCommas(n)
	return tostring(math.floor(n)):reverse():gsub("(%d%d%d)","%1,")
								  :gsub(",(%-?)$","%1"):reverse()
end

-- Events
RegisterServerEvent('wasabi_multijob:saveJob')
AddEventHandler('wasabi_multijob:saveJob', function(job)
    local xPlayer = ESX.GetPlayerFromId(source)
    local identifier = xPlayer.identifier
    MySQL.single('SELECT job FROM wasabi_multijob WHERE identifier = ? AND job = ?', {identifier, job.name}, function(result)
        if result then
            MySQL.update('UPDATE wasabi_multijob SET grade = ? WHERE identifier = ? AND job = ?', {job.grade, identifier, job.name}, function(affectedRows) end)
        else
            MySQL.Async.execute('INSERT INTO wasabi_multijob (identifier, job, grade) VALUES (@identifier, @job, @grade)', {
                ['@identifier'] = identifier,
                ['@job'] = job.name,
                ['@grade'] = job.grade,
            }, function(rowsChanged)
            end)
        end
    end)
end)

RegisterServerEvent('wasabi_multijob:fireEmployee')
AddEventHandler('wasabi_multijob:fireEmployee', function(data)
    local xTarget = ESX.GetPlayerFromIdentifier(data.user.identifier)
    if xTarget and xTarget.job.name == data.job then
        xTarget.setJob(Config.offDutyJob.name, Config.offDutyJob.grade)
    else
        MySQL.Async.execute('UPDATE users SET job = @job, job_grade = @job_grade WHERE identifier = @identifier', {
            ['@identifier'] = data.user.identifier,
            ['@job'] = Config.offDutyJob.name,
            ['@job_grade'] = Config.offDutyJob.grade,
        }, function(rowsChanged)
            if rowsChanged then
            end
        end)
    end
    MySQL.Async.execute('DELETE FROM `wasabi_multijob` WHERE `identifier` = @identifier AND job = @job', {
        ["@identifier"] = data.user.identifier,
        ["@job"] = data.job
    })
end)

RegisterServerEvent('wasabi_multijob:deleteJob')
AddEventHandler('wasabi_multijob:deleteJob', function(data)
    local xPlayer = ESX.GetPlayerFromId(source)
    local job = data.job
    MySQL.Async.execute('DELETE FROM `wasabi_multijob` WHERE `identifier` = @identifier AND job = @job', {
        ["@identifier"] = xPlayer.identifier,
        ["@job"] = job
	})
    if xPlayer.job.name == job then
        xPlayer.setJob(Config.offDutyJob.name, Config.offDutyJob.grade)
    end
end)

RegisterServerEvent('wasabi_multijob:ClockIn')
AddEventHandler('wasabi_multijob:ClockIn', function(data)
    local xPlayer = ESX.GetPlayerFromId(source)
    xPlayer.setJob(data.job, data.grade)
end)

RegisterServerEvent('wasabi_multijob:clockOut')
AddEventHandler('wasabi_multijob:clockOut', function()
    local xPlayer = ESX.GetPlayerFromId(source)
    xPlayer.setJob(Config.offDutyJob.name, Config.offDutyJob.grade)
end)

--Callbacks
lib.callback.register('wasabi_multijob:loadData', function(source)
    while not loaded do Wait() end
    local xPlayer = ESX.GetPlayerFromId(source)
    local data = {jobs = jobs}
    local userJobs, finished = {}, false
    MySQL.Async.fetchAll('SELECT job, grade FROM wasabi_multijob WHERE identifier = @identifier', {
        ['@identifier'] = xPlayer.identifier,
    }, function(result)
        if result[1] then
            for i=1, #result do
                if jobs[result[i].job] and jobs[result[i].job].grades[result[i].grade] then
                    userJobs[#userJobs + 1] = {job = result[i].job, grade = result[i].grade}
                else
                    MySQL.Async.execute('DELETE FROM wasabi_multijob WHERE identifier = @identifier AND job = @job AND grade = @grade', {
                        ["@identifier"] = xPlayer.identifier,
                        ["@job"] = result[i].job,
                        ["@grade"] = result[i].grade
                    })
                end
            end
            finished = userJobs
        else
            finished = true
        end
    end)
    while not finished do Wait() end
    if type(finished) == 'table' then
        data.userJobs = finished
        return data
    else
        return data
    end
end)

lib.callback.register('wasabi_multijob:getUserJobs', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    local userJobs, finished = {}, false
    MySQL.Async.fetchAll('SELECT job, grade FROM wasabi_multijob WHERE identifier = @identifier', {
        ['@identifier'] = xPlayer.identifier,
    }, function(result)
        if result[1] then
            for i=1, #result do
                if jobs[result[i].job] and jobs[result[i].job].grades[result[i].grade] then
                    userJobs[#userJobs + 1] = {job = result[i].job, grade = result[i].grade}
                else
                    MySQL.Async.execute('DELETE FROM wasabi_multijob WHERE identifier = @identifier AND job = @job AND grade = @grade', {
                        ["@identifier"] = xPlayer.identifier,
                        ["@job"] = result[i].job,
                        ["@grade"] = result[i].grade
                    })
                end
            end
            finished = userJobs
        else
            finished = true
        end
    end)
    while not finished do Wait() end
    if type(finished) == 'table' then return finished else return empty end
end)

lib.callback.register('wasabi_multijob:openBossMenu', function(source, job)
    local employees, finished = {}, nil
    MySQL.Async.fetchAll('SELECT identifier, job, grade FROM wasabi_multijob WHERE job = @job', {
        ['@job'] = job,
    }, function(result)
        if result[1] then
            for i=1, #result do
                employees[#employees + 1] = {
                    identifier = result[i].identifier,
                    name = users[result[i].identifier],
                    grade = result[i].grade
                }
            end
            finished = true
        else
            finished = true
        end
    end)
    while not finished do Wait() end
    return employees
end)

lib.callback.register('wasabi_multijob:hireEmployee', function(source, id, job)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer.job.name == job and xPlayer.job.grade_name == 'boss' then
        local zPlayer = ESX.GetPlayerFromId(id)
        if not zPlayer then return false end
        if jobs[job].grades?[0] then
            zPlayer.setJob(job, 0)
        else
            zPlayer.setJob(job, 1)
        end
        return zPlayer.getName()
    end
end)

lib.callback.register('wasabi_multijob:canDeposit', function(source, amount, job)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer.job.name == job and xPlayer.job.grade_name == 'boss' then
        local xMoney = xPlayer.getAccount(Config.bossMenus.depositAccount).money
        if xMoney >= amount then
            xPlayer.removeAccountMoney(Config.bossMenus.depositAccount, amount)
            TriggerEvent('esx_addonaccount:getSharedAccount', 'society_'..job, function(account)
                account.addMoney(amount)
            end)
            return true
        else
            return false
        end
    end
end)

lib.callback.register('wasabi_multijob:canWithdrawal', function(source, amount, job)
    local xPlayer = ESX.GetPlayerFromId(source)
    local withdrawaled = false
    if xPlayer.job.name == job and xPlayer.job.grade_name == 'boss' then
        TriggerEvent('esx_addonaccount:getSharedAccount', 'society_'..job, function(account)
            if amount > 0 and account.money >= amount then
                account.removeMoney(amount)
                withdrawaled = true
            end
        end)
        if withdrawaled then
            xPlayer.addAccountMoney(Config.bossMenus.withdrawalAccount, amount)
            return true
        else
            return false
        end
    end
end)

lib.callback.register('wasabi_multijob:canGiveBonus', function(source, data, amount)
    local xPlayer = ESX.GetPlayerFromId(source)
    local job, grade, identifier, name = data.job, data.grade, data.user.identifier, data.user.name
    local success = false
    if not xPlayer.job.name == job or not xPlayer.job.grade_name == 'boss' then return false end
	TriggerEvent('esx_addonaccount:getSharedAccount', 'society_'..job, function(account)
		if amount > 0 and account.money >= amount then
			account.removeMoney(amount)
            local xTarget = ESX.GetPlayerFromIdentifier(identifier)
            if xTarget then
                TriggerClientEvent('wasabi_multijob:notify', source, Strings.success, (Strings.bonus_success_desc):format(name, addCommas(amount)))
                TriggerClientEvent('wasabi_multijob:notify', xTarget.source, Strings.bonus_title, (Strings.bonus_desc):format(addCommas(amount), jobs[job].label))
			    xTarget.addAccountMoney('bank', amount)
                success = true
			else
                local sent = giveOfflineBonus(identifier, amount)
                if sent then
                    TriggerClientEvent('wasabi_multijob:notify', source, Strings.success, (Strings.bonus_success_desc):format(name, addCommas(amount)))
                    success = true
                end
            end
		end
	end)
    return success
end)

lib.callback.register('wasabi_multijob:setRank', function(source, data)
    local job, grade, identifier = data.job, data.grade, data.user.identifier
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer.job.name == job or not xPlayer.job.grade_name == 'boss' then return false end
    local xTarget = ESX.GetPlayerFromIdentifier(identifier)
    if xTarget and xTarget.job.name == job then
        xTarget.setJob(job, grade)
    elseif not xTarget then
        MySQL.single('SELECT job, job_grade FROM users WHERE identifier = ?', {identifier}, function(result)
            if result then
                if result.job == job and result.grade ~= grade then
                    MySQL.Async.execute('UPDATE users SET job_grade = @grade WHERE identifier = @identifier', {
                        ['@grade'] = grade,
                        ['@identifier'] = identifier,
                    }, function(rowsChanged)
                    end)
                end
            end
        end)
    end
    MySQL.Async.execute('UPDATE wasabi_multijob SET grade = @grade WHERE identifier = @identifier and job = @job', {
        ['@grade'] = grade,
        ['@identifier'] = identifier,
        ['@job'] = job,
    }, function(rowsChanged)
    end)
    return true
end)

-- In case restart of script while server running
AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        Wait(4500)
		TriggerClientEvent('wasabi_multijob:resourceRestart', -1)
	end
end)
