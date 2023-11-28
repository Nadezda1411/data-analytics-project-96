with visitors_and_leads as (
    select distinct on (s.visitor_id)
        s.visitor_id,
        s.visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        l.lead_id,
        l.closing_reason,
        l.amount,
        l.created_at,
        l.status_id
from sessions s
left join leads l
    on s.visitor_id = l.visitor_id 
    and s.visit_date <= l.created_at
where s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
order by 1, 2 DESC
),
costs as (
   select
       campaign_date::date,
       SUM(daily_spent) as daily_spent,
       utm_source,
       utm_medium,
       utm_campaign
   from vk_ads
   group by 1,3,4,5
   union all
   select
       campaign_date::date,
       SUM(daily_spent) as daily_spent,
       utm_source,
       utm_medium,
       utm_campaign
   from ya_ads
   group by 1,3,4,5
)  
select
    vl.visit_date::date,
    vl.utm_source,
    vl.utm_medium,
    vl.utm_campaign,
    COUNT(*) as visitors_count,
    SUM(coalesce(daily_spent, 0)) as total_cost,
    COUNT(*) filter (where lead_id is not NULL) as leads_count,
    COUNT(*) filter (where status_id = 142) as purchases_count,
    coalesce(SUM(amount) filter (where status_id = 142), 0) as revenue
from visitors_and_leads vl
left join costs c
    on vl.utm_source = c.utm_source
    and vl.utm_medium = c.utm_medium
    and vl.utm_campaign = c.utm_campaign
    and vl.visit_date = c.campaign_date
group by 1,2,3,4
order by 9 desc nulls last, 5 desc, 1,2,3,4;