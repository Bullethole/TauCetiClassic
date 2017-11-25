/*
	TODO README
*/

var/list/fusion_cores = list()

#define MAX_FIELD_STR 1000
#define MIN_FIELD_STR 1

/obj/machinery/power/fusion_core
	name = "R-UST Mk. 8 Tokamak core"
	desc = "An enormous solenoid for generating extremely high power electromagnetic fields. It includes a kinetic energy harvester."
	icon = 'icons/obj/machines/power/fusion.dmi'
	icon_state = "core0"
	density = TRUE
	use_power = TRUE
	idle_power_usage = 50
	active_power_usage = 500 //multiplied by field strength
	anchored = FALSE
	interact_offline = TRUE // WE WANT TO HUG TOKAMAK EVEN UNDER NOPOWER STAT!! WEEEEE

	var/obj/effect/fusion_em_field/owned_field
	var/field_strength = 1//0.01
	var/id_tag

/obj/machinery/power/fusion_core/mapped
	anchored = TRUE

/obj/machinery/power/fusion_core/atom_init()
	. = ..()
	if(anchored)
		connect_to_network()
	fusion_cores += src

/obj/machinery/power/fusion_core/Destroy()
	for(var/obj/machinery/computer/fusion_core_control/FCC in machines)
		FCC.connected_devices -= src
		if(FCC.cur_viewed_device == src)
			FCC.cur_viewed_device = null
	fusion_cores -= src
	return ..()

/obj/machinery/power/fusion_core/process()
	if((stat & BROKEN) || !powernet || !owned_field || !anchored)
		Shutdown()

/obj/machinery/power/fusion_core/Topic(href, href_list)
	if(!..())
		return
	if(href_list["str"])
		var/dif = text2num(href_list["str"])
		field_strength = Clamp(field_strength + dif, MIN_FIELD_STR, MAX_FIELD_STR)
		active_power_usage = 500 * field_strength
		if(owned_field)
			owned_field.ChangeFieldStrength(field_strength)

/obj/machinery/power/fusion_core/proc/Startup()
	if(owned_field || !anchored)
		return
	owned_field = new(loc, src)
	owned_field.ChangeFieldStrength(field_strength)
	icon_state = "core1"
	use_power = 2
	. = TRUE

/obj/machinery/power/fusion_core/proc/Shutdown(force_rupture)
	if(owned_field)
		icon_state = "core0"
		if(force_rupture || owned_field.plasma_temperature > 1000)
			owned_field.Rupture()
		else
			owned_field.RadiateAll()
		qdel(owned_field)
		owned_field = null
	use_power = 1

/obj/machinery/power/fusion_core/proc/AddParticles(name, quantity = 1)
	if(owned_field)
		owned_field.AddParticles(name, quantity)
		. = TRUE

/obj/machinery/power/fusion_core/bullet_act(obj/item/projectile/Proj)
	if(owned_field)
		. = owned_field.bullet_act(Proj)

/obj/machinery/power/fusion_core/proc/set_strength(value)
	value = Clamp(value, MIN_FIELD_STR, MAX_FIELD_STR)
	field_strength = value
	active_power_usage = 5 * value
	if(owned_field)
		owned_field.ChangeFieldStrength(value)

/obj/machinery/power/fusion_core/attack_ai(mob/user) // As funny as it was for the AI to hug-kill the tokamak field from a distance...
	if(IsAdminGhost(user))
		return ..()

/obj/machinery/power/fusion_core/attack_hand(mob/user)
	. = ..()
	if(.)
		return

	visible_message("<span class='notice'>\The [user] hugs \the [src] to make it feel better!</span>")
	if(owned_field)
		Shutdown()

/obj/machinery/power/fusion_core/attackby(obj/item/W, mob/user)

	if(owned_field)
		to_chat(user,"<span class='warning'>Shut \the [src] off first!</span>")
		return

	if(ismultitool(W))
		var/new_ident = input("Enter a new ident tag.", "Fusion Core", id_tag) as null|text
		if(new_ident && user.Adjacent(src))
			id_tag = new_ident
		return

	else if(iswrench(W))
		anchored = !anchored
		playsound(src.loc, 'sound/items/Ratchet.ogg', 75, 1)
		if(anchored)
			connect_to_network()
			user.visible_message("[user.name] secures [src.name] to the floor.", \
				"You secure the [src.name] to the floor.", \
				"You hear a ratchet")
		else
			disconnect_from_network()
			user.visible_message("[user.name] unsecures [src.name] from the floor.", \
				"You unsecure the [src.name] from the floor.", \
				"You hear a ratchet")
		return

	return ..()

/obj/machinery/power/fusion_core/proc/jumpstart(field_temperature)
	field_strength = 501 // Generally a good size.
	Startup()
	if(!owned_field)
		return FALSE
	owned_field.plasma_temperature = field_temperature
	return TRUE