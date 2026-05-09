local Timer = {
    timers = {}
}

function Timer.after(delay, callback)
    table.insert(Timer.timers, {
        timeLeft = delay,
        callback = callback,
    })
end

function Timer.clear()
    Timer.timers = {}
end

function Timer.update(dt)
    for i = #Timer.timers, 1, -1 do
        local timer = Timer.timers[i]
        timer.timeLeft = timer.timeLeft - dt
        if timer.timeLeft <= 0 then
            timer.callback()
            table.remove(Timer.timers, i)
        end
    end
end

return Timer
