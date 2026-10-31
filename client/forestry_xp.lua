-- XP feedback is cosmetic; server updates the existing progression table.
RegisterNetEvent('wonkys_landscaping:forestry:xp',function(amount,kind)
    local label=kind=='logs' and 'Timber collected' or 'Leaf waste collected'
    lib.notify({title="Wonky's Forestry",description=('%s: +%d XP'):format(label,amount),type='success',duration=3500})
end)
