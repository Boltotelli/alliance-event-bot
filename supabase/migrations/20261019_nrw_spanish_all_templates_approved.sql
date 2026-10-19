begin;
-- Explicit authorization on 2026-10-19 to publish all existing NRW Event Bot Spanish templates.
-- These 14 template groups cover 17 rules because 4 Championship reminders share a text.
update public.aos_discord_bot_config set channels = jsonb_set(channels,'{es}','"1561701242659410021"'::jsonb,true),updated_at=now() where alliance_code='NRW';
update public.aos_discord_message_rules set messages=jsonb_set(messages,'{es}',to_jsonb($translate_es$💢 **FIN DE SEMANA FIGHT CLUB** 💢

💥 **Triforce** 💥 SÁBADO
👉 Legión 1: **14:00 UTC**
👉 Legión 2: **19:00 UTC**

💥 **Swordland** 💥 DOMINGO
👉 Legión 1: **14:00 UTC**
👉 Legión 2: **19:00 UTC**

⚠️ **¡Inscríbete en la batalla SOLO si realmente puedes participar!** 🙏$translate_es$::text),true) where alliance_code='NRW' and event_key='catalog-tri-alliance-clash';
update public.aos_discord_message_rules set messages=jsonb_set(messages,'{es}',to_jsonb($translate_es$⚔️ **¡Táctica de alianza para los Capitanes de César!** ⚔️

🎯 ¡Empezad atacando con **UN SOLO soldado y SIN héroes**!

Así todos los miembros activos de la alianza podrán dar al menos un golpe 🎯 y recibir las recompensas. 🏆

✅ **¡No terminaremos el combate hasta que todos hayan atacado al menos una vez!** 💥

🚀 Cuando digamos **«GO»**, ¡atacad con toda vuestra fuerza!

💰🔥 ¡Así conseguiremos las máximas recompensas para toda la alianza!

💙 ¡Gracias por vuestra colaboración!$translate_es$::text),true) where alliance_code='NRW' and event_key='cesare';
update public.aos_discord_message_rules set messages=jsonb_set(messages,'{es}',to_jsonb($translate_es$🏆 **Campeonato de Alianza – ¡Inscripción!**

⚔️ **Usad las siguientes formaciones de tropas:**

💪 Más de 250 M de poder total: **60/40/0**
💪 Menos de 250 M de poder total: **50/20/30**

🐾 ¡Activad las bonificaciones de mascotas para la Trampa del Oso antes de inscribiros!

🎯 **¡Inscribíos SOLO en el CARRIL CENTRAL!**

⚠️ **¿Ya te has inscrito? ¡Vuelve a inscribirte para actualizar tu formación y bonificaciones!**$translate_es$::text),true) where alliance_code='NRW' and event_key='championship';
update public.aos_discord_message_rules set messages=jsonb_set(messages,'{es}',to_jsonb($translate_es$💎 **Consejos para Eternity's Reach**

💰 Derrotad guardianes hasta desbloquear la habilidad 3. Luego usad todas las marchas excepto una contra los guardianes, y la restante para ocupar vetas.

💰 ¡No hace falta recolectar mucho tiempo!
Ocupad una veta, obtened **+5000 puntos**, retirad las tropas y volved a enviarlas al cabo de un minuto.

💰 Reservad la habilidad 5 para las erupciones de vetas. ¡Cuando aparezcan, enviad **TODAS las marchas** a recolectar!

💰 Teletransportaos si la zona está demasiado concurrida.

🌳 **Mejor orden del árbol de habilidades:**
➡️ Derecha → Derecha → Izquierda → Izquierda → Derecha$translate_es$::text),true) where alliance_code='NRW' and event_key='eternity';
update public.aos_discord_message_rules set messages=jsonb_set(messages,'{es}',to_jsonb($translate_es$📅 **¡Programa para hoy!**

🎯 ¡Consigamos más puntos para la fase de preparación de mañana!

🕒 **UTC | Completar | Reclamar**

🌙 00:00 | ✅ | ✅
🌅 08:00 | ✅ | ❌
☀️ 16:00 | ❌ | ❌
🌙 00:00* | ✅ | ✅

✅ = Completar / Reclamar
❌ = No completar / No reclamar

🐼 **¡Activa las misiones de inteligencia extra de Pan después de las 16:00 UTC!**

⭐ *00:00 = ¡Después del próximo reinicio!*$translate_es$::text),true) where alliance_code='NRW' and event_key='golden';
update public.aos_discord_message_rules set messages=jsonb_set(messages,'{es}',to_jsonb($translate_es$⚔️ **¡El evento de eliminación comienza esta noche!**

Está permitido atacar tropas que recolectan recursos. Solo puedes recolectar con seguridad dentro del centro de la alianza.

🚫 **¡Está prohibido atacar ciudades!**

**Excepciones:**

* Ciudades de jugadores sin alianza
* Ciudades de alianzas con un solo miembro

🏥 ¡Mantén la enfermería lo más vacía posible!

🏰 También puedes ganar puntos del evento durante la Batalla del Castillo.

✅ Tras la Batalla del Castillo podrás volver a recolectar recursos con seguridad en cualquier lugar.$translate_es$::text),true) where alliance_code='NRW' and event_key='kill';
update public.aos_discord_message_rules set messages=jsonb_set(messages,'{es}',to_jsonb($translate_es$👑 **Guía de preparación KvK** 👑
 １   ２　３    ４    ５
✅｜👍｜✅｜👍｜✅｜Inteligencia
✅｜🆗｜🚫｜🚫｜🆗｜Oro verdadero (TG)
🆗｜✅｜🚫｜🚫｜🆗｜Polvo de oro
🚫｜✅｜🆗｜🚫｜🚫｜Fragmentos de héroe
✅｜🆗｜🚫｜🚫｜🆗｜Aceleradores de construcción
🚫｜🚫｜🚫｜✅｜🆗｜Aceleradores de tropas
🆗｜✅｜🚫｜🚫｜🆗｜Aceleradores de investigación
🚫｜✅｜🆗｜🚫｜🚫｜Ruleta
👍｜✅｜👍｜✅｜✅｜Recolección
🚫｜🚫｜✅｜🚫｜✅｜Mejora de mascotas
🆗｜🚫｜🆗｜✅｜🚫｜Talismán del gobernador
🚫｜🚫｜🚫｜🚫｜✅｜Equipo del gobernador
🚫｜🚫｜🚫｜🆗｜✅｜Widget
🚫｜🚫｜🚫｜🆗｜✅｜Mitrilo
🚫｜🚫｜🚫｜🆗｜✅｜Martillos de forja
🚫｜✅｜✅｜🚫｜🚫｜Emblemas de maestro
🚫｜✅｜✅｜🚫｜🚫｜Manuscritos de maestro

✅ mejor día 🆗 aceptable 🚫 no usar 👍 diario$translate_es$::text),true) where alliance_code='NRW' and event_key='kvk' and title='Prep Phase vollständig';
update public.aos_discord_message_rules set messages=jsonb_set(messages,'{es}',to_jsonb($translate_es$🎯 **KvK Día 1:**

🪙 Oro verdadero y polvo de oro verdadero
✨ Talismanes del gobernador
😎 Misiones de inteligencia
🏗️ Aceleradores de construcción
📕 Aceleradores de aprendizaje*

*Hoy NO es el día para mejorar las habilidades y relaciones de los maestros. ¡Eso toca el día 3!

🐑 Envía recolectores con antelación para que regresen después del comienzo del día 2.$translate_es$::text),true) where alliance_code='NRW' and event_key='kvk' and title='Tag 1 Missionen';
update public.aos_discord_message_rules set messages=jsonb_set(messages,'{es}',to_jsonb($translate_es$🎯 **KvK Día 2:**

🪙 Oro verdadero y polvo de oro verdadero
📕 Aceleradores de investigación
🎰 Gira la ruleta de héroes, pero guarda algunos giros para mañana
🍭 Usa fragmentos de héroe
🍞 Recolecta recursos

👀 ¡Guarda las misiones de inteligencia de las 16:00 para mañana!

💪 Usa una bonificación de capacidad de entrenamiento para preparar tropas que estarán listas el día 4.$translate_es$::text),true) where alliance_code='NRW' and event_key='kvk' and title='Tag 2 Missionen';
update public.aos_discord_message_rules set messages=jsonb_set(messages,'{es}',to_jsonb($translate_es$🎯 **KvK Día 3:**

🐶 Mejora y refina mascotas
✨ Mejora los talismanes del gobernador
🎰 Gira la ruleta de héroes
🍭 Usa fragmentos de héroe
💕 Mejora las relaciones de maestros con emblemas de maestro
📕 Mejora las habilidades de maestros con manuscritos de maestro
👀 Completa las misiones de inteligencia

🐑 Envía recolectores con antelación para que regresen después del comienzo del día 4.$translate_es$::text),true) where alliance_code='NRW' and event_key='kvk' and title='Tag 3 Missionen';
update public.aos_discord_message_rules set messages=jsonb_set(messages,'{es}',to_jsonb($translate_es$🎯 **KvK Día 4:**

💪 Entrena o asciende tropas
✨ Mejora talismanes (¡último día para hacerlo!)
🔨 Usa martillos de forja
⚽ Mejora widgets de héroes
🎽 Usa mitrilo
🍞 Recolecta recursos$translate_es$::text),true) where alliance_code='NRW' and event_key='kvk' and title='Tag 4 Missionen';
update public.aos_discord_message_rules set messages=jsonb_set(messages,'{es}',to_jsonb($translate_es$⚔️ **¡Día de batalla KvK!**

🛡️ ¡El servidor enemigo podría atacarnos a partir de las **10:00 UTC**!

⚠️ ¡**NO activéis los escudos ahora**! ¡Activadlos poco antes de las **10:00 UTC**!$translate_es$::text),true) where alliance_code='NRW' and event_key='kvk' and title='KVK Kampfinfo 1';
update public.aos_discord_message_rules set messages=jsonb_set(messages,'{es}',to_jsonb($translate_es$🚨 **¡ATENCIÓN! ¡ATAQUE ENEMIGO!** 🚨

🛡️ **¡Activad los escudos AHORA!**

⚔️ ¡El servidor enemigo podría atacarnos en **30 minutos**!

⚠️ **¡Aseguraos de que vuestras ciudades estén protegidas!**$translate_es$::text),true) where alliance_code='NRW' and event_key='kvk' and title='KVK Kampfinfo 2';
update public.aos_discord_message_rules set messages=jsonb_set(messages,'{es}',to_jsonb($translate_es$🎯 **KvK Día 5:**

🐶 Mejora y refina mascotas
🎸 Mejora el equipo del gobernador
🔨 Usa martillos de forja
⚽ Mejora widgets
🎽 Usa mitrilo
🪙 Oro verdadero y polvo de oro verdadero
🏃 Usa todos los aceleradores
👀 Misiones de inteligencia
🍞 Recolecta recursos$translate_es$::text),true) where alliance_code='NRW' and event_key='kvk' and title='Tag 5 Missionen';
do $checks$
declare
  rule_count integer;
  translated_count integer;
  invalid_count integer;
begin
 select count(*), count(*) filter(where nullif(trim(messages->>'es'),'') is not null),
 count(*) filter(where length(messages->>'es')>1800)
 into rule_count,translated_count,invalid_count
 from public.aos_discord_message_rules where alliance_code='NRW';
 if rule_count<>17 or translated_count<>rule_count or invalid_count<>0 then
  raise exception 'Spanish template validation failed: %, %, %',rule_count,translated_count,invalid_count;
 end if;
 if not exists (
  select 1 from public.aos_discord_bot_config
  where alliance_code='NRW'
    and channels->>'es'='1561701242659410021'
 ) then raise exception 'Spanish channel not configured';end if;
end $checks$;
-- Reopen ONLY previously paused future Spanish slots, never previously sent/skipped messages
-- nor expired slots, preventing catch-up pings.
update public.aos_event_bot_outbox
set status='planned',error_code=null,error_detail=null,updated_at=now()
where alliance_code='NRW' and language='es'
 and source_type in ('cycle','manual') and status='cancelled'
 and error_code='spanish_not_approved'
 and scheduled_at > clock_timestamp()+interval '3 minutes'
 and attempts=0 and discord_message_id is null;
-- Rehydrate role/channel/text fields and create any new future Spanish slots.
select public.aos_event_bot_refresh() as refreshed;
select public.aos_event_bot_refresh_manual() as refreshed_manual;
commit;
