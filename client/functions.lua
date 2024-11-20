-----------------For support, scripts, and more----------------
--------------- https://discord.gg/wasabiscripts  -------------
---------------------------------------------------------------
local onShift

function addCommas(n)
	return tostring(math.floor(n)):reverse():gsub("(%d%d%d)","%1,")
								  :gsub(",(%-?)$","%1"):reverse()
end

function CheckJob(job)
    if job.name == Config.offDutyJob.name or Config.blacklist[job.name] then return end
    UserJobs = lib.callback.await('wasabi_multijob:getUserJobs', 100)
    while not UserJobs do Wait() end
    local found
    for _,v in pairs(UserJobs) do
        if v.job == job.name then
            found = true
            break
        end
    end
    if found then return end
    if Config.maxJobs and #UserJobs >= Config.maxJobs then return end
    TriggerServerEvent('wasabi_multijob:saveJob', job)
    UserJobs[job.name] = job.grade
    lib.alertDialog({
        header = Strings.hired_header,
        content = Strings.hired_content,
        centered = true,
        cancel = false
    })
    onShift = true
end

function ToggleDuty(job) -- Use for next update
    local duty = lib.callback.await('wasabi_multijob:toggleDuty', 100, job)
    if duty then
        TriggerEvent('wasabi_multijob:notify', Strings.clocked_in, Strings.clocked_in_desc, 'inform')
    else
        TriggerEvent('wasabi_multijob:notify', Strings.clocked_out, Strings.clocked_out_desc, 'inform')
    end
end

function SelectJobMenu(data)
    lib.registerContext({
		id = 'job_select',
		title = Jobs[data.job].label,
		options = {
			{
				title = Strings.go_back,
				description = '',
				event = 'wasabi_multijob:openJobMenu',
				args = data.job
			},
			{
				title = Strings.clock_in,
				description = '',
				event = 'wasabi_multijob:clockIn',
				args = {job = data.job, grade = data.grade}
			},
			{
				title = Strings.clock_out,
				description = '',
				event = 'wasabi_multijob:clockOut',
				args = {job = data.job, grade = data.grade}
			},
			{
				title = Strings.delete_job,
				description = '',
				event = 'wasabi_multijob:deleteJob',
				args = {job = data.job, grade = data.grade}
			},
		}
	})
	lib.showContext('job_select')
end

function OpenJobMenu()
    UserJobs = lib.callback.await('wasabi_multijob:getUserJobs', 100)
    local Options = {}
    if UserJobs then
        if ESX.PlayerData.job.name == Config.offDutyJob.name then
            Options[#Options + 1] = {
                title = Strings.offduty_header,
                icon = 'briefcase',
                description = '',
                event = 'wasabi_multijob:closeMenu',
                arrow = true,
            }
        else
            Options[#Options + 1] = {
                title = Strings.clockedin_job..' '..ESX.PlayerData.job.label,
                icon = 'briefcase',
                description = '',
                event = 'wasabi_multijob:clockOut',
                arrow = true
            }
        end
        for i=1, #UserJobs do
            Options[#Options + 1] = {
                title = Jobs[UserJobs[i].job].label,
                description = Strings.grade_label..' '..Jobs[UserJobs[i].job].grades[UserJobs[i].grade].label,
                event = 'wasabi_multijob:selectJobMenu',
                args = {job = UserJobs[i].job, grade = UserJobs[i].grade}
            }
        end
    else
        Options = {
            {
                title = Strings.no_jobs,
                description = Strings.nojob_desc,
                event = 'wasabi_multijob:closeMenu',
                arrow = true
            }
        }
    end
    lib.registerContext({
        id = 'jobs_menu',
        title = Strings.jobs_menu,
        options = Options
    })
    lib.showContext('jobs_menu')
end

--Boss Menu functions

function DepositFunds(job)
    local input = lib.inputDialog(Strings.deposit_funds, {Strings.amount})
    if input then
        local amount = math.floor(input[1])
		if amount > 0 then
            local canDeposit = lib.callback.await('wasabi_multijob:canDeposit', 100, amount, job)
            if canDeposit then
                BossData.funds = BossData.funds + amount
                TriggerEvent('wasabi_multijob:notify', Strings.deposit_successful, (Strings.deposit_successful_desc):format(addCommas(amount)))
                ManageFunds(job)
            else
                TriggerEvent('wasabi_multijob:notify', Strings.lacking_funds, Strings.lacking_funds_desc, 'error')
                ManageFunds(job)
            end
		else
            TriggerEvent('wasabi_multijob:notify', Strings.invalid_amount, Strings.invalid_amount_desc, 'error')
			ManageFunds(job)
		end
    end
end

function WithdrawalFunds(job)
    local input = lib.inputDialog(Strings.withdrawal_funds, {Strings.amount})
    if input then
        local amount = math.floor(input[1])
		if amount > 0 then
            if BossData.funds >= amount then
                local canWithdrawal = lib.callback.await('wasabi_multijob:canWithdrawal', 100, amount, job)
                if canWithdrawal then
                    BossData.funds = BossData.funds - amount
                    TriggerEvent('wasabi_multijob:notify', Strings.withdrawal_successful, (Strings.withdrawal_successful_desc):format(addCommas(amount)), 'success')
                    ManageFunds(job)
                else
                    TriggerEvent('wasabi_multijob:notify', Strings.lacking_funds, Strings.lacking_funds_desc, 'error')
                    ManageFunds(job)
                end
            else
                TriggerEvent('wasabi_multijob:notify', Strings.lacking_funds, Strings.lacking_funds_desc, 'error')
                ManageFunds(job)
            end
		else
            TriggerEvent('wasabi_multijob:notify', Strings.invalid_amount, Strings.invalid_amount_desc, 'error')
            ManageFunds(job)
		end
    end
end

function ManageFunds(job)
	if not ESX.PlayerData.job.name == job or not ESX.PlayerData.job.grade_name == 'boss' then return end
    lib.registerContext({
        id = 'manage_funds',
        title = Strings.society_funds_desc..' '..Strings.currency..addCommas(BossData.funds),
        options = {
            {
                title = Strings.go_back,
                description = '',
                event = 'wasabi_multijob:mainMenu',
                args = job
            },
            {
                title = Strings.deposit_funds,
                description = '',
                event = 'wasabi_multijob:depositFunds',
                args = job
            },
            {
                title = Strings.withdrawal_funds,
                description = '',
                event = 'wasabi_multijob:withdrawalFunds',
                args = job
            },
        }
    })
    lib.showContext('manage_funds')
end

function SetRank(data)
    if not lib.callback.await('wasabi_multijob:setRank', 100, data) then return end
    for k,v in ipairs(BossData.employees) do
        if v.identifier == data.user.identifier then
            v.grade = data.grade
            break
        end
    end
    TriggerEvent('wasabi_multijob:notify', Strings.success, Strings.success_desc, 'success')
    data.user.grade = data.grade
    EditRank(data)
end

function EditRank(data)
    if not ESX.PlayerData.job.name == data.job or not ESX.PlayerData.job.grade_name == 'boss' then return end
    local job, user = data.job, data.user
    local Options = {
		{
		title = Strings.go_back,
		description = '',
		event = 'wasabi_multijob:editEmployee',
		args = data
		}
	}
	for k,v in pairs(Jobs[job].grades) do
		if k ~= user.grade then
            Options[#Options + 1] = {
                title = v.label,
                description = Strings.job_salary..' '..Strings.currency..addCommas(v.salary),
                event = 'wasabi_multijob:setRank',
                args = {job = job, user = user, grade = k}
            }
		else
            Options[#Options + 1] = {
                title = v.label..' '..Strings.current_position,
				description = Strings.job_salary..' '..Strings.currency..addCommas(v.salary),
				event = 'wasabi_multijob:editEmployee',
				args = data
            }
		end
	end
	lib.registerContext({
		id = 'edit_rank',
		title = user.name..' - '..Jobs[job].grades[user.grade].label,
		options = Options
	})
	lib.showContext('edit_rank')
end

function GiveBonus(data)
    if not ESX.PlayerData.job.name == data.job or not ESX.PlayerData.job.grade_name == 'boss' then return end
    local job, user = data.job, data.user
    local input = lib.inputDialog(Strings.give_bonus, {Strings.amount})
    if input then
        local amount = math.floor(input[1])
		if amount > 0 then
            if BossData.funds >= amount then
                local success = lib.callback.await('wasabi_multijob:canGiveBonus', 100, data, amount)
                if success then
                    BossData.funds = BossData.funds - amount
                    EditEmployee(data)
                else
                    TriggerEvent('wasabi_multijob:notify', Strings.unsuccessful, Strings.went_wrong_desc, 'error')
                    EditEmployee(data)
                end
            else
                TriggerEvent('wasabi_multijob:notify', Strings.lacking_funds, Strings.lacking_funds_desc, 'error')
            end
		else
            TriggerEvent('wasabi_multijob:notify', Strings.invalid_amount, Strings.invalid_amount_desc, 'error')
		end
	end
end

function HireEmployee(job)
    if not ESX.PlayerData.job.name == job or not ESX.PlayerData.job.grade_name == 'boss' then return end
    local input = lib.inputDialog(Strings.hire_employee, {Strings.id})
    if input then
        local id = math.floor(input[1])
		if id > 0 then
            local hired = lib.callback.await('wasabi_multijob:hireEmployee', 100, id, job)
            if hired then
                TriggerEvent('wasabi_multijob:notify', Strings.success, (Strings.success_hire):format(hired), 'success')
            else
                TriggerEvent('wasabi_multijob:notify', Strings.unsuccessful, Strings.unsuccessful_hire, 'error')
            end
		end
	end
end

function EditEmployee(data)
    if not ESX.PlayerData.job.name == data.job or not ESX.PlayerData.job.grade_name == 'boss' then return end
    local job, user = data.job, data.user
	lib.registerContext({
		id = 'edit_employee',
		title = user.name,
		options = {
			{
				title = Strings.go_back,
				description = '',
				event = 'wasabi_multijob:manageEmployees',
				args = job
			},
			{
				title = Strings.edit_rank,
                description = (Strings.edit_rank_desc):format(Jobs[job].grades[user.grade].label, addCommas(Jobs[job].grades[user.grade].salary)),
				event = 'wasabi_multijob:editRank',
				args = {job = job, user = user}
			},
			{
				title = Strings.give_bonus,
				description = Strings.give_bonus_desc,
				event = 'wasabi_multijob:giveBonus',
				args = {job = job, user = user}
			},
			{
				title = Strings.fire_employee,
				description = '',
				event = 'wasabi_multijob:fireEmployee',
				args = {job = job, user = user}
			},
		}
	})
	lib.showContext('edit_employee')
end

function ManageEmployees(job, user)
    if not ESX.PlayerData.job.name == job or not ESX.PlayerData.job.grade_name == 'boss' then return end
    local Options = {
        {
            title = Strings.go_back,
            description = '',
            event = 'wasabi_multijob:mainMenu',
            args = job
        }
    }
    for k,v in pairs(BossData.employees) do
        if not user or user ~= v.identifier then
            Options[#Options + 1] = {
                title = v.name,
                description = Strings.job_position..' '..Jobs[job].grades[v.grade].label,
                event = 'wasabi_multijob:editEmployee',
                args = {user = v, job = job}
            }
        end
    end
    lib.registerContext({
        id = 'manage_employees',
        title = Strings.employee_list,
        options = Options
    })
    lib.showContext('manage_employees')
end

function OpenBossMenu(job)
    if not ESX.PlayerData.job.name == job or not ESX.PlayerData.job.grade_name == 'boss' then return end
    ESX.TriggerServerCallback('esx_society:getSocietyMoney', function(money)
        BossData.employees = lib.callback.await('wasabi_multijob:openBossMenu', 100, job)
        if BossData.employees then
            lib.registerContext({
                id = 'bossmenu',
                title = Jobs[job].label,
                options = {
                    {
                        title = Strings.society_funds,
                        icon = 'money-bill-wave',
                        description = Strings.society_funds_desc..' '..Strings.currency..''..addCommas(money or 0),
                        event = 'wasabi_multijob:manageFunds',
                        args = job
                    },
                    {
                        title = Strings.employee_list,
                        icon = 'people-group',
                        description = (Strings.employee_count):format(#BossData.employees),
                        event = 'wasabi_multijob:manageEmployees',
                        args = job
                    },
                    {
                        title = Strings.hire_employee,
                        icon = 'person-circle-plus',
                        description = Strings.hire_employee_desc,
                        event = 'wasabi_multijob:hireEmployee',
                        args = job
                    },
                }
            })
            BossData.funds = money
            lib.showContext('bossmenu')
        end
    end, job)
end

exports('openBossMenu', OpenBossMenu)
