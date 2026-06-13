with users as(
--Таблиця 1 Вибираємо необхідні дані: АйДі користувача, дата входу, маркер залучення, 
	select user_id,
			signup_datetime,
			promo_signup_flag,
			--Робота з датою входу
			case 
				-- Очищуємо дату: видаляємо пробіли, вирізаємо час (залишаюючи лише дату), замінюємо роздільники на "/"використовуючи регулярний вираз,
				-- Визначаємо довжину тексту щоб перевірити коректність року, приводимо до формату дати
				when length(regexp_replace(split_part(trim(signup_datetime), ' ', 1), '[.-]', '/', 'g')) = 10
				then to_date(regexp_replace(split_part(trim(signup_datetime), ' ', 1), '[.-]', '/', 'g'), 'DD/MM/YYYY')
				when length(regexp_replace(split_part(trim(signup_datetime), ' ', 1), '[.-]', '/', 'g')) between 6 and 9
				then to_date(regexp_replace(split_part(trim(signup_datetime), ' ', 1), '[.-]', '/', 'g'), 'DD/MM/YY')
				else null
			end as clear_signup_date
	from project.cohort_users_raw u),
events as (
--Таблиця 2 Вибираємо необхідні дані: АйДі користувача, тип події
	select user_id ,
			event_type ,
			--Робота з датою події
			case
				-- Очищуємо дату: аналогічно таблиці 1
				when length(regexp_replace(split_part(trim(event_datetime), ' ', 1), '[.-]', '/', 'g')) = 10
				then to_date(regexp_replace(split_part(trim(event_datetime), ' ', 1), '[.-]', '/', 'g'), 'dd/mm/yyyy')
				when length(regexp_replace(split_part(trim(event_datetime), ' ', 1), '[.-]', '/', 'g')) between 6 and 9
				then to_date(regexp_replace(split_part(trim(event_datetime), ' ', 1), '[.-]', '/', 'g'), 'DD/MM/YY')
				else null
			end as clear_event_date
	from project.cohort_events_raw e),
user_activity as (
--Таблиця 3 Об'єднуємо попередні таблиці по АйДі користувача, виводимо місяць входу користувача, місяць активності та стаж
	select u.user_id,
			date_trunc('month', u.clear_signup_date)::date as cohort_month,
			u.promo_signup_flag, 
			DATE_TRUNC('month', e.clear_event_date)::date as activity_month,
			--Стаж каристувача: вибираємо лише місяць з дат входу та активності,знаходимо різницю в місяцях
			EXTRACT(MONTH FROM AGE(DATE_TRUNC('month', e.clear_event_date), DATE_TRUNC('month', u.clear_signup_date))) as month_offset
	from users u
	join events e 
	on u.user_id = e.user_id
	--Виключаємо "пусті" значення, виключаємо тестові події
	where u.clear_signup_date is not null 
	and e.clear_event_date is not null
	and e.event_type is not null 
	and e.event_type != 'test_event')
--Кінцевий результат: виводимо маркер залучення, місяць входу, стаж, кулькість унікальних користувачів 
select promo_signup_flag, 
		cohort_month, 
		month_offset,
		count(distinct user_id) as users_total
from user_activity
--Обмежуємо період
where activity_month between '2025-01-01'and '2025-06-01'
group by 1,2,3
order by 1,2,3