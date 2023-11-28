
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
    from sessions s
    left join leads l
        on s.visitor_id = l.visitor_id
        and l.created_at >= s.visit_date
    where s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
    order by 1, 2 desc)

select * from table1
order by 8 desc nulls last, 2, 3, 4, 5;

