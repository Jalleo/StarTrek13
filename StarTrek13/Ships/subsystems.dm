/obj/structure/shipsystem_console
	name = "a shipsystem console"
	desc = "A console that sits over a chair, how are you seeing this?."
	icon = 'StarTrek13/icons/trek/star_trek.dmi'
	icon_state = "helm"
	anchored = TRUE
	density = 1
	opacity = 0
	layer = 4.5
	var/datum/subsytem/system //shipsystems are a datum, will also attach onto ships, one console controls one shipsystem.
	var/list/linked_objects = list()
	var/object_type = /obj/item //redundant, waiting on super here

/obj/structure/shipsystem_console/proc/fail()
	for(var/atom/movable/T in linked_objects)
		if(istype(T, object_type))
			qdel(T)

/datum/shipsystem_controller
	var/current_subsytems = 0 //How many shipsystems are attached to the controller?
	var/fail_rate = 0 //this will be a %age
	var/obj/structure/overmap/theship
	var/datum/shipsystem/shields/shields
	var/datum/shipsystem/weapons/weapons
	var/datum/shipsystem/integrity/hull_integrity
	var/datum/shipsystem/sensors/sensors
	var/datum/shipsystem/engines/engines
	var/list/systems = list()

/datum/shipsystem_controller/proc/generate_shipsystems()
	shields = new()
	shields.controller = src
	weapons = new()
	weapons.controller = src
	sensors = new()
	sensors.controller = src
	engines = new()
	engines.controller = src
	systems += shields
	systems += weapons
	systems += sensors
	systems += engines

/datum/shipsystem_controller/proc/take_damage(amount) ///if the shipsystem controller takes damage, that means the enemy ship didn't pick a system to disable. So pick one at random, there is a chance that the hull will glance off the hit.
	var/list/thesystems() = systems
	var/datum/shipsystem/thetarget = pick(thesystems)//Don't want to damage the hull twice!
	thetarget.take_damage(amount)


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	Alrighty, so our shipsystem controller will hold all the shipsystems, you'll be able to monitor it through the shipsystem monitors, where you can overclock and such, play with the power draw and all that goodness.	//
//  Then it's just a case of adding the shipsystem controller to the overmap ship, it'll handle the rest																													//
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


//Begin shipsystems!//

/datum/shipsystem
	var/integrity = 10000 //Will be a percentage, if this drops too low the shipsystem will fail, affecting the ship. EG sensors going down means goodbye sight for the pilot of the ship.
	var/max_integrity = 10000 //maximum susbsytem health, so that I can do percentage calculations.
	var/power_draw = 0 //Not used yet
	var/overclock = 0 //Overclock a shipsystem to get better performance, at a higher power draw. Numbers pending warp core and power code
	var/efficiency = 40 //as a percent, we take our desired effect, such as weapons power, and divide it by this, so a 600 damage rated phaser would be 600*40%, so 40% of 600, in other words; 240 damage. You'll want to be overclocking tbh.
	var/failed = FALSE //If failed, do not process, cut the shipsystem and other such scary things.
	var/list/linked_objects()
	var/integrity_sensitive = TRUE
	var/datum/shipsystem_controller/controller
	var/power_supplied = 0 //How much power is available right now? until we connect these to the powernet, it'll just be done by snowflake EPS conduits.
 //How hot has it got? if this heat goes above 100, expect performance decreases
	var/name = "subsystem"
	var/heat = 0

/datum/shipsystem/New()
	. = ..()
	start()

/datum/shipsystem/proc/start()
	START_PROCESSING(SSobj, src)
	failed = 0

/datum/shipsystem/proc/lose_heat(amount)
	if(heat) //  < 0
		heat -= amount

/datum/shipsystem/process()//Here's where the magic happens.
	if(integrity > max_integrity)
		integrity = max_integrity
	if(heat < 0)
		heat = 0
	if(!failed)
		if(heat)
			integrity -= heat
		if(integrity <= 5000) //Subsystems will autofail when they're this fucked
			failed = TRUE
			fail()
			//So stop processing
		if(overclock > 0) //Drain power.
			power_draw += overclock //again, need power stats to fiddle with.
	else
		if(integrity > 5000) //reactivate
			failed = FALSE

/datum/shipsystem/proc/fail()
	failed = TRUE
	for(var/obj/structure/shipsystem_console/T in linked_objects)
		T.fail()

/datum/shipsystem/proc/take_damage(amount)
	integrity -= amount

/datum/shipsystem/proc/calculate_percentages()
	var/thenumber = round(100* integrity / max_integrity) //aka, percentage for ease of reading
	return thenumber

/datum/shipsystem/proc/repair_damage(amount)
	integrity += amount
	if(integrity >= max_integrity)
		integrity = max_integrity


/datum/shipsystem/weapons
	power_draw = 0//just so it's not an empty type TBH. We can tweak this later when we get power in.
	name = "weapons"
	var/damage = 1
	var/fire_cost = 1
	var/max_charge = 1
	var/chargeRate = 1
	var/delay = 0
	var/max_delay = 2 //2 ticks to fire again, this is ontop of phaser charge times
	var/charge = 0
	var/maths_damage = 0 //After math is applied, how much damage? in relation to how much charge they have etc.

//	theship.damage = 0	//R/HMMM
//	theship.phaser_fire_cost = 0
///	theship.max_charge = 0
//	theship.phaser_charge_rate = 0

/datum/shipsystem/weapons/proc/update_weapons()
	damage = initial(damage)
	fire_cost = initial(fire_cost)
	max_charge = initial(max_charge)
	chargeRate = initial(chargeRate)
	var/counter = 0
	var/temp = 0
	for(var/obj/machinery/power/ship/phaser/P in controller.theship.weapons.weapons)
		chargeRate += P.charge_rate
		damage += P.damage
		fire_cost += P.fire_cost
		counter ++
		temp = P.charge
	maths_damage = damage
	maths_damage -= round(max_charge - charge)/2 //Damage drops off heavily if you don't let them charge
	damage = maths_damage
	max_charge += counter*temp //To avoid it dropping to 0 on update, so then the charge spikes to maximum due to process()

/datum/shipsystem/weapons/process()
	. = ..()
	charge += chargeRate
	if(integrity > max_integrity)
		integrity = max_integrity
	if(heat < 0)
		heat = 0
	if(charge > max_charge)
		charge = max_charge
	if(heat)
		integrity -= heat
	if(integrity <= 5000) //Subsystems will autofail when they're this fucked
		failed = 1
		fail()
		//So stop processing
	if(overclock > 0) //Drain power.
		power_draw += overclock //again, need power stats to fiddle with.

/datum/shipsystem/weapons/proc/attempt_fire()
	if(charge >= fire_cost)
		maths_damage = damage
		maths_damage -= round(max_charge - charge)/1.7 //Damage drops off heavily if you don't let them charge
		damage = maths_damage
		charge -= fire_cost
		heat += fire_cost / 0.7
		return 1
	else
		return 0


/datum/shipsystem/sensors
	power_draw = 0//just so it's not an empty type TBH.
	name = "sensors"

/datum/shipsystem/engines
	power_draw = 0//just so it's not an empty type TBH.
	name = "engines"

/datum/shipsystem/shields
	name = "shields"
	max_integrity = 20000 //in this case, integrity is shield health. If your shields are smashed to bits, it's assumed that all the control circuits are pretty fried anyways.
	var/breakingpoint = 50 //at 50 heat, shields will take double damage
	var/heat_resistance = 2 // how much we resist gaining heat
	power_draw = 0//just so it's not an empty type TBH.
	var/list/obj/machinery/space_battle/shield_generator/linked_generators = list()
	var/regen_bonus = 10 //Bonus health gained per tick for having shield systems in-tact.
	var/active = FALSE
	var/obj/structure/ship_component/capbooster/boosters = list()

/datum/shipsystem/shields/fail()
	..()
	for(var/obj/machinery/space_battle/shield_generator/S in linked_generators)
		for(var/obj/effect/adv_shield/S2 in S.shields)
			S2.deactivate()
			S2.active = FALSE
		controller.theship.shields_active = FALSE
	failed = TRUE

/datum/shipsystem/shields/process()
	var/our_bonus = 0 //How many capboosters are in the ship?
	max_integrity = initial(max_integrity)
	for(var/obj/structure/ship_component/capbooster in boosters)
		our_bonus += 5000
	max_integrity = initial(max_integrity) + our_bonus
	if(integrity > max_integrity)
		integrity = max_integrity
	if(heat < 0)
		heat = 0
	if(!failed && active)
		controller.theship.shield_health = integrity
		if(heat)
			integrity -= heat
		if(integrity <= 5000) //Subsystems will autofail when they're this fucked
			failed = 1
			fail()
			active = FALSE
		if(overclock > 0) //Drain power.
			power_draw += overclock //again, need power stats to fiddle with.
		if(heat >= 1000) //Don't let them get this hot. Please.
			regen_bonus = -50
		if(heat >= 100 && heat < 1000)
			regen_bonus = 100
		else
			regen_bonus = 200
		if(controller.theship.shields_active)
			heat += 10 //Keeping your shields up makes them heat up.
		else
			heat -= 30 //Rapidly cool
	else //failed IE. forcibly taken down
		heat -= 50 //Cools down because not in use
		if(integrity > 5000) //bring them back online, it's repaired.
			failed = FALSE
			active = TRUE
	integrity += regen_bonus

//round(100 * value / max_value PERCENTAGE CALCULATIONS, quick maths.
//U3VwZXIgaXMgYmFk

/obj/structure/subsystem_component
	name = "EPS Conduit"
	desc = "this supplies power to a subsystem."
	icon = 'StarTrek13/icons/trek/subsystem_parts.dmi'
	icon_state = "conduit"
	anchored = 1
	density = 0
	can_be_unanchored = 0


/obj/structure/fluff/helm/desk
	name = "desk computer"
	desc = "A generic deskbuilt computer"
	icon = 'StarTrek13/icons/trek/star_trek.dmi'
	icon_state = "desk"
	anchored = TRUE
	density = 1 //SKREE
	opacity = 0
	layer = 4.5

/obj/structure/fluff/helm/desk/functional
	name = "shield station"
	var/obj/structure/overmap/ship/our_ship
	var/datum/shipsystem/shields/subsystem
	var/mob/living/carbon/human/crewman

/obj/structure/fluff/helm/desk/functional/nt
	icon_state = "computer"

/obj/structure/fluff/helm/desk/functional/weapons
	name = "weapons station"
	/datum/shipsystem/weapons/subsystem

/obj/structure/fluff/helm/desk/functional/weapons/nt
	icon_state = "computer"

/obj/structure/fluff/helm/desk/functional/New()
	. = ..()

/obj/structure/fluff/helm/desk/functional/proc/get_ship()
	subsystem = our_ship.SC.shields

/obj/structure/fluff/helm/desk/functional/weapons/get_ship()
	subsystem = our_ship.SC.weapons

/obj/structure/fluff/helm/desk/functional/attack_hand(mob/living/user)
	to_chat(user, "You are now manning [src], with your expertise you'll provide a boost to the [subsystem] subsystem. You need to remain still whilst doing this.")
	if(crewman)
		crewman = null
	crewman = user
	START_PROCESSING(SSobj, src)

/obj/structure/fluff/helm/desk/functional/process() //A good mini boost to a subsystem which will help keep your ship alive just a liiil longer.
	if(crewman in orange(1, src))
		subsystem.integrity += 30 //numbers pending balance
		subsystem.heat -= 30
		subsystem.heat_resistance = 4
		return
	else
		to_chat(crewman, "You are too far away from [src], and have stopped managing the [subsystem] subsystem.")
		crewman = null
		subsystem.heat_resistance = initial(subsystem.heat_resistance)
		STOP_PROCESSING(SSobj, src)


/obj/structure/subsystem_monitor
	name = "LCARS display"
	desc = "It is some kind of monitor which allows you to look at the health of the ship."
	icon = 'StarTrek13/icons/trek/star_trek.dmi'
	icon_state = "lcars"
	var/datum/shipsystem/shields/subsystem //change me as you need. This one's for testing
	var/obj/structure/overmap/ship/our_ship

/obj/structure/subsystem_monitor/proc/get_ship()
	subsystem = our_ship.SC.shields

/obj/structure/subsystem_monitor/examine(mob/user)
	. = ..()
	to_chat(user, "Status of: [subsystem.name] subsystem: Integrity: [subsystem.integrity] Heat: [subsystem.heat] Current overclock factor: [subsystem.overclock]")

/obj/structure/subsystem_monitor/weapons
	icon_state = "lcars2"
	name = "tactical display"
	/datum/shipsystem/weapons/subsystem

/obj/structure/subsystem_monitor/weapons/get_ship()
	subsystem = our_ship.SC.weapons


/obj/structure/overmap/proc/get_damageable_components()
	for(var/obj/structure/ship_component/L in linked_ship)
		components += L
		L.our_ship = src
		L.chosen = SC.shields

//Sparks, smoke, fire, breaches, roof falls on heads


/obj/structure/ship_component		//so these lil guys will directly affect subsystem health, they can get damaged when the ship takes hits, so keep your hyperfractalgigaspanners handy engineers!
	name = "coolant manifold"
	desc = "a large manifold carrying supercooled coolant gas to the ship's subsystems, you should take care to maintain it to avoid malfunctions!"
	icon = 'StarTrek13/icons/trek/subsystem_parts.dmi'
	icon_state = "coolant"
	var/damage_message = "ruptures!"
	var/health = 100
	var/obj/structure/overmap/our_ship
	var/datum/shipsystem/shields/chosen
	var/active = FALSE
	var/benefit_amount = 300 //How much will you gain in health/lose in heat with this component active?
	var/can_be_reactivated = TRUE

/obj/structure/ship_component/New()
	. = ..()
	START_PROCESSING(SSobj,src)

/obj/structure/ship_component/examine(mob/user)
	if(active)
		. = ..()
		to_chat(user, "it is active, and cooling the [chosen.name] subsystem by [benefit_amount] per second.")
		return
	else
		return ..()

/obj/structure/ship_component/ex_act(severity)
	health -= severity*10

/obj/structure/ship_component/process()
	if(active)
		health -= 2 //Make sure to keep it in good repair
		check_health()
		apply_subsystem_bonus()
		if(health > initial(health))
			health = initial(health)
	else
		if(health >= 20)
			can_be_reactivated = TRUE

/obj/structure/ship_component/take_damage(amount)
	health -= amount
	visible_message("[src] is hit!")
	check_health()

/obj/structure/ship_component/proc/check_health()
	if(health >= 100)
		icon_state = initial(icon_state)
		return
	else if(health <100 && health >20)
		icon_state = "[initial(icon_state)]-damaged"
	else
		active = FALSE
		can_be_reactivated = FALSE
		fail()

/obj/structure/ship_component/proc/fail()
	playsound(loc, 'sound/effects/bamf.ogg', 50, 2)
	visible_message("[src] [damage_message]")
	var/datum/effect_system/smoke_spread/freezing/smoke = new
	smoke.set_up(10, loc)
	smoke.start()
	playsound(loc, 'StarTrek13/sound/borg/machines/alert1.ogg', 50, 2)
	active = FALSE
	can_be_reactivated = FALSE


/obj/structure/ship_component/proc/apply_subsystem_bonus() //Each component will have a benefit to subsystems when activated, coolant manifolds will regenerate some subsystem health as long as they are alive and active.
	if(active)
		chosen.lose_heat(benefit_amount)
		return 1
	else
		return 0

/obj/structure/ship_component/attack_hand(mob/living/H)
	if(can_be_reactivated)
		if(!active)
			to_chat(H, "You activate [src]!")
			active = TRUE
		else
			to_chat(H, "You de-activate [src]!")
			active = FALSE
	else
		to_chat(H, "[src] is too badly damaged! repair it first!")


/obj/structure/ship_component/attackby(obj/item/I,mob/living/user)
	if(istype(I, /obj/item/wrench))
		to_chat(user, "You're repairing [src] with [I]")
		if(do_after(user, 5, target = src))
			to_chat(user, "You patch up some of the dents in [src]!")
			health += 10


/obj/structure/ship_component/capbooster
	name = "capacitor booster"
	icon_state = "capbooster"
	desc = "This component will increase the effective strength of your shields when active, at the expense of an increased heat output."

/obj/structure/ship_component/capbooster/examine(mob/user)
	. = ..()
	if(active)
		to_chat(user, "It is active")
	else
		to_chat(user, "It is not active")

/obj/structure/ship_component/capbooster/process()//apply_subsystem_bonus() //Each component will have a benefit to subsystems when activated, coolant manifolds will regenerate some subsystem health as long as they are alive and active.
	if(active)
		chosen.heat += 10
		chosen.boosters += src
		return 1
	else
		chosen.boosters -= src
		return 0



// var/thenumber1 = rand(20,40)
// var/thenumber2 = rand(20,50)
// var/theanswer = number1 + number2
// to_chat(user, "Enemy ship unsigned vector X : Mark unsigned vector Y. Phase drift modulation: X + Y = [theanswer].