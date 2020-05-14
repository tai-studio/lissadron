local myModule = {}

function myModule.range(array, the_start, the_end)
    local out = {}
    for i=the_start,the_end do
        out[i-the_start+1] = array[i]
    end
    return out
end

function myModule.rotate(array, shift)
    local out = {}
    for i=0,(#array-1) do
        local idx = (i+shift)% #array
        -- print(idx)
        out[idx+1] = array[i+1]
    end
    return out
end

function myModule.print(array)
    print("{" .. table.concat(array, ", ") .. "}")
end

function myModule.bjorklund(steps, pulses, shift)
    if pulses > steps then
        pulses = steps
    end
    local pattern = {}
    local counts = {}
    local remainders = {}
    local divisor = steps - pulses
    
    remainders[1] = pulses

    -- return remainders

    local level = 0
    while true do
        counts[#counts +1 ] = divisor // remainders[level+1]
        remainders[#remainders+1] = divisor % remainders[level+1]
        divisor = remainders[level+1]
        level = level + 1
        if remainders[level+1] <= 1 then
            break
        end
    end

    counts[#counts+1] = divisor
    
    -- print(level)
    -- print("")
    -- print(table.concat(counts, ", "))
    -- print("")
    -- print(table.concat(remainders, ", "))



    do
        local function _build(myLevel)
            if (myLevel == -1) then
                pattern[#pattern+1] = 0
            elseif (myLevel == -2) then
                pattern[#pattern+1] = 1
            else
                -- print(myLevel)
                -- print("counts" .. counts[myLevel+1])

                for i=0,(counts[myLevel+1]-1) do
                    _build(myLevel-1)
                end
                if (remainders[myLevel+1] ~= 0) then
                    _build(myLevel-2)
                end
                -- print(table.concat(pattern, ", "))
            end
        end

        _build(level)
    end

    local idxOne = 0
    for i=1,#pattern do
        if pattern[i] == 1 then
            pattern = myModule.rotate(pattern, #pattern - (i-1))
            break
        end
    end
    pattern = myModule.rotate(pattern, shift)

    return pattern
end


return myModule