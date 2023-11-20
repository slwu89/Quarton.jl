
using DataStructures

export Queue, InfiniteSourceQueue, FIFOQueue, SinkQueue, RandomQueue, total_work
export FiniteFIFOQueue

abstract type Queue end

id!(q::Queue, id::Int) = (q.id = id; q)
id(q::Queue) = q.id


mutable struct FIFOQueue <: Queue
    deque::Deque{Tuple{Token,Time}}
    retire_cnt::Int
    retire_total_duration::Time
    id::Int
    FIFOQueue() = new(Deque{Tuple{Token,Time}}(), zero(Int), zero(Time), zero(Int))
end

Base.push!(q::FIFOQueue, token, when) = push!(q.deque, (token, when))

function update_downstream!(q::FIFOQueue, downstream, when, rng)
    s_available = available_servers(downstream)
    shuffle!(rng, s_available)
    for s in s_available
        if !isempty(q.deque)
            token, emplace_time = popfirst!(q.deque)
            q.retire_cnt += 1
            q.retire_total_duration += when - emplace_time
            push!(downstream, s, token)
        end
    end
    nothing
end

total_work(q::FIFOQueue) = sum(workload(w) for w in q.deque)

throughput(q::FIFOQueue) = q.retire_cnt / q.retire_total_duration

mutable struct InfiniteSourceQueue <: Queue
    create_cnt::Int
    id::Int
    builder::Function
    InfiniteSourceQueue(builder=(when, rng)->Work(1.0, when)) =
            new(zero(Int), zero(Int), builder)
end

function update_downstream!(q::InfiniteSourceQueue, downstream, when, rng)
    for s in available_servers(downstream)
        q.create_cnt += 1
        token = q.builder(when, rng)
        @assert workload(token) > 0.0
        push!(downstream, s, token)
    end
    nothing
end


mutable struct SinkQueue <: Queue
    retire_cnt::Int
    retire_total_duration::Time
    id::Int
    SinkQueue() = new(zero(Int), zero(Time), zero(Int))
end


function Base.push!(q::SinkQueue, token, when)
    q.retire_cnt += 1
    q.retire_total_duration += when - created(token)
end


throughput(q::SinkQueue) = q.retire_cnt / q.retire_total_duration

update_downstream!(q::SinkQueue, downstream, when, rng) = nothing
total_work(q::SinkQueue) = 0  # This will be a type problem. Need the token type.


mutable struct RandomQueue <: Queue
    queue::Vector{Tuple{Token,Time}}
    retire_cnt::Int
    retire_total_duration::Time
    id::Int
    RandomQueue() = new(Vector{Tuple{Token,Time}}(), zero(Int), zero(Time), zero(Int))
end

Base.push!(q::RandomQueue, token, when) = push!(q.queue, (token, when))

function update_downstream!(q::RandomQueue, downstream, when, rng)
    s_available = available_servers(downstream)
    shuffle!(rng, s_available)
    for s in s_available
        if !isempty(q.queue)
            take_idx = rand(rng, 1:length(q.queue))
            token, emplace_time = q.queue[take_idx]
            deleteat!(q.queue, take_idx)
            q.retire_cnt += 1
            q.retire_total_duration += when - emplace_time
            push!(downstream, s, token)
        end
    end
    nothing
end

total_work(q::RandomQueue) = sum(workload(w) for w in q.queue)

throughput(q::RandomQueue) = q.retire_cnt / q.retire_total_duration


mutable struct FiniteFIFOQueue <: Queue
    deque::Deque{Tuple{Token,Time}}
    limit::Int
    retire_cnt::Int
    retire_total_duration::Time
    drop_cnt::Int
    id::Int
    FiniteFIFOQueue(limit::Int) = new(
        Deque{Tuple{Token,Time}}(), limit, zero(Int), zero(Time), zero(Int), zero(Int)
        )
end

function Base.push!(q::FiniteFIFOQueue, token, when)
    if length(q.deque) <= q.limit
        push!(q.deque, (token, when))
    else
        q.drop_cnt += 1
    end
end

function update_downstream!(q::FiniteFIFOQueue, downstream, when, rng)
    s_available = available_servers(downstream)
    shuffle!(rng, s_available)
    for s in s_available
        if !isempty(q.deque)
            token, emplace_time = popfirst!(q.deque)
            q.retire_cnt += 1
            q.retire_total_duration += when - emplace_time
            push!(downstream, s, token)
        end
    end
    nothing
end

total_work(q::FiniteFIFOQueue) = sum(workload(w) for w in q.deque)

throughput(q::FiniteFIFOQueue) = q.retire_cnt / q.retire_total_duration
