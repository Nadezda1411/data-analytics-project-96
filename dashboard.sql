-- Основной запрос (таблица results)

with visitors_and_leads as (
    select distinct on (s.visitor_id)
        s.visitor_id,
        s.visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        l.lead_id,
        l.amount,
        l.created_at,
        l.status_id
    from sessions as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
    where s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
    order by 1, 2 desc
),

costs as (
    select
        campaign_date::date,
        SUM(daily_spent) as daily_spent,
        utm_source,
        utm_medium,
        utm_campaign
    from vk_ads
    group by 1, 3, 4, 5
    union all
    select
        campaign_date::date,
        SUM(daily_spent) as daily_spent,
        utm_source,
        utm_medium,
        utm_campaign
    from ya_ads
    group by 1, 3, 4, 5
),

results as (
    select
        vl.visit_date::date,
        COUNT(*) as visitors_count,
        vl.utm_source,
        vl.utm_medium,
        vl.utm_campaign,
        daily_spent as total_cost,
        COUNT(*) filter (where lead_id is not NULL) as leads_count,
        COUNT(*) filter (where status_id = 142) as purchases_count,
        COALESCE(SUM(amount) filter (where status_id = 142), 0) as revenue
    from visitors_and_leads as vl
    left join costs as c
        on
            vl.utm_source = c.utm_source
            and vl.utm_medium = c.utm_medium
            and vl.utm_campaign = c.utm_campaign
            and vl.visit_date::date = c.campaign_date::date
    group by 1, 3, 4, 5, 6
    order by 9 desc nulls last, 2 desc, 1, 3, 4, 5
)


-- общее количество посетителей, лидов, успешно завершенных сделок, каналов привлечения

select
    SUM(visitors_count),
    SUM(leads_count),
    SUM(purchases_count),
    COUNT(distinct utm_source) as count_utm_source
from results;


-- количество посетителей по каждому каналу по неделям

select
    case
        when visit_date between '2023-06-01' and '2023-06-04' then '1_week'
        when visit_date between '2023-06-05' and '2023-06-11' then '2_week'
        when visit_date between '2023-06-12' and '2023-06-18' then '3_week'
        when visit_date between '2023-06-19' and '2023-06-25' then '4_week'
        when visit_date between '2023-06-26' and '2023-06-30' then '5_week'
    end
    as week,
    utm_source,
    SUM(visitors_count) as visitors_count
from results
group by 1, 2
order by 1, 3 desc;


-- конверсия из клика в лид, из лида в оплату

select
    ROUND(SUM(leads_count) / SUM(visitors_count) * 100, 2) as conversion_leads,
    ROUND(SUM(purchases_count) / SUM(leads_count) * 100, 2) as conversion_paid
from results;


-- суммарные затраты на рекламу и суммарная выручка

select
    SUM(total_cost),
    SUM(revenue)
from results;


-- CPU, CPL, CPPU, ROI

select
    ROUND(COALESCE(SUM(total_cost), 0) / SUM(visitors_count), 2) as cpu,
    ROUND(COALESCE(SUM(total_cost), 0) / SUM(leads_count), 2) as cpl,
    ROUND(COALESCE(SUM(total_cost), 0) / SUM(purchases_count), 2) as cppu,
    ROUND((SUM(revenue) - SUM(total_cost)) / SUM(total_cost) * 100, 2) as roi
from results;


-- CPU, CPL, CPPU, ROI по utm_sourse

select
    utm_source,
    ROUND(COALESCE(SUM(total_cost), 0) / SUM(visitors_count), 2) as cpu,
    ROUND(COALESCE(SUM(total_cost), 0) / SUM(leads_count), 2) as cpl,
    ROUND(COALESCE(SUM(total_cost), 0) / SUM(purchases_count), 2) as cppu,
    ROUND((SUM(revenue) - SUM(total_cost)) / SUM(total_cost) * 100, 2) as roi
from results
group by 1
having SUM(total_cost) is not null;


-- CPU по utm_medium

select
    utm_medium,
    ROUND(COALESCE(SUM(total_cost), 0) / SUM(visitors_count), 2) as cpu
from results
group by 1
having SUM(visitors_count) != 0;


-- CPL по utm_medium

select
    utm_medium,
    ROUND(COALESCE(SUM(total_cost), 0) / SUM(leads_count), 2) as cpl
from results
group by 1
having SUM(leads_count) != 0;


-- CPPU по utm_medium

select
    utm_medium,
    ROUND(COALESCE(SUM(total_cost), 0) / SUM(purchases_count), 2) as cppu
from results
group by 1
having SUM(purchases_count) != 0;


-- ROI по utm_medium

select
    utm_medium,
    ROUND((SUM(revenue) - SUM(total_cost)) / SUM(total_cost) * 100, 2) as roi
from results
group by 1
having SUM(total_cost) != 0;


-- CPU по utm_campaign

select
    utm_campaign,
    round(coalesce(sum(total_cost), 0) / sum(visitors_count), 2) as cpu
from results
group by 1
having sum(visitors_count) != 0
order by 2 desc;


-- CPL по utm_campaign

select
    utm_campaign,
    round(coalesce(sum(total_cost), 0) / sum(leads_count), 2) as cpl
from results
group by 1
having sum(leads_count) != 0
order by 2 desc;


-- CPPU по utm_campaign

select
    utm_campaign,
    round(coalesce(sum(total_cost), 0) / sum(purchases_count), 2) as cppu
from results
group by 1
having sum(purchases_count) != 0
order by 2 desc;


-- ROI по utm_campaign

select
    utm_campaign,
    round((sum(revenue) - sum(total_cost)) / sum(total_cost) * 100, 2) as roi
from results
group by 1
having sum(total_cost) != 0
order by 2 desc;


-- затраты на рекламу, выручка по каналам

select
    utm_source,
    sum(coalesce(total_cost, 0)) as source_total_cost,
    sum(coalesce(revenue, 0)) as source_revenue
from results
group by 1
order by 2 desc, 3 desc;


-- корреляция между запуском рекламной кампании и ростом органики:

with organic as (
    select
        visit_date::date as visit_date,
        COUNT(*) as count_organic
    from sessions
    where medium = 'organic'
    group by 1
),

daily_costs as (
    select
        utm_source,
        utm_medium,
        utm_campaign,
        utm_content,
        daily_spent
    from vk_ads
    union all
    select
        utm_source,
        utm_medium,
        utm_campaign,
        utm_content,
        daily_spent
    from ya_ads
),

source_and_costs as (
    select
        s.visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        s.content as utm_content,
        dc.daily_spent
    from sessions as s
    inner join daily_costs as dc
        on
            s.source = dc.utm_source
            and s.medium = dc.utm_medium
            and s.campaign = dc.utm_campaign
            and s.content = dc.utm_content
),

total_costs as (
    select
        visit_date::date as visit_date,
        SUM(daily_spent) as total_cost
    from source_and_costs
    group by 1
)

select
    o.visit_date,
    tc.total_cost,
    o.count_organic
from organic as o
inner join total_costs as tc
    on o.visit_date = tc.visit_date
order by 1;

-- дата закрытия лидов

with table1 as (
    select distinct on (s.visitor_id)
        s.visitor_id,
        s.visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id
    from sessions as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
    where s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
    order by 1, 2 desc
),

visitors_and_leads as (
    select * from table1
    order by 8 desc nulls last, 2, 3, 4, 5
),

date_close as (
    select
        lead_id,
        created_at as date_close
    from visitors_and_leads
    where lead_id is not null
    order by 2
)

select
    date_close::date,
    COUNT(*) as leads_count
from date_close
group by 1
order by 1;


-- кол-во дней с момента перехода по рекламе до закрытия лида

with table1 as (
    select distinct on (s.visitor_id)
        s.visitor_id,
        s.visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id
    from sessions as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
    where s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
    order by 1, 2 desc
),

visitors_and_leads as (
    select * from table1
    order by 8 desc nulls last, 2, 3, 4, 5
),

days_close as (
    select
        lead_id,
        created_at::date - visit_date::date as days_close
    from visitors_and_leads
    where lead_id is not null
    order by 2
)

select
    days_close,
    COUNT(*) as leads_count
from days_close
group by 1
order by 1;
