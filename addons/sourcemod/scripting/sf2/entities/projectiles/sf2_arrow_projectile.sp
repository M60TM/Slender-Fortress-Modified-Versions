#pragma semicolon 1

static const char g_EntityClassname[] = "sf2_projectile_arrow";

static CEntityFactory g_Factory;

methodmap SF2_ProjectileArrow < SF2_ProjectileBase
{
	public SF2_ProjectileArrow(int entIndex)
	{
		return view_as<SF2_ProjectileArrow>(CBaseAnimating(entIndex));
	}

	public bool IsValid()
	{
		if (!CBaseAnimating(this.index).IsValid())
		{
			return false;
		}

		return CEntityFactory.GetFactoryOfEntity(this.index) == g_Factory;
	}

	public static void Initialize()
	{
		g_Factory = new CEntityFactory(g_EntityClassname);
		g_Factory.DeriveFromFactory(SF2_ProjectileBase.GetFactory());
		g_Factory.BeginDataMapDesc()
			.DefineBoolField("m_Touched")
			.EndDataMapDesc();
		g_Factory.Install();
	}

	property bool Touched
	{
		public get()
		{
			return this.GetProp(Prop_Data, "m_Touched") != 0;
		}

		public set(bool value)
		{
			this.SetProp(Prop_Data, "m_Touched", value);
		}
	}

	public static SF2_ProjectileArrow Create(
		const CBaseEntity owner,
		const float pos[3],
		const float ang[3],
		const float speed,
		const float damage,
		const bool isCrits,
		const char[] trail,
		const char[] impactSound,
		const char[] model,
		const bool attackWaiters = false)
	{
		SF2_ProjectileArrow arrow = SF2_ProjectileArrow(CreateEntityByName(g_EntityClassname));
		if (!arrow.IsValid())
		{
			return SF2_ProjectileArrow(-1);
		}

		arrow.Type = SF2BossProjectileType_Arrow;
		arrow.Speed = speed;
		arrow.Damage = damage;
		if (arrow.IsCrits)
		{
			CBaseEntity critParticle = arrow.CreateParticle("critical_rocket_blue");
			arrow.CritEntity = critParticle;
		}
		arrow.AttackWaiters = attackWaiters;
		arrow.SetImpactSound(impactSound);
		SetEntityOwner(arrow.index, owner.index);
		arrow.SetModel(model);
		arrow.KeyValue("solid", "2");

		arrow.Spawn();
		arrow.Activate();
		arrow.SetMoveType(MOVETYPE_FLYGRAVITY);
		arrow.SetProp(Prop_Send, "m_usSolidFlags", 12);
		arrow.Teleport(pos, ang, NULL_VECTOR);
		arrow.CreateTrail(true, "effects/arrowtrail_red.vmt", "255", "1");
		arrow.SetVelocity();

		SDKHook(arrow.index, SDKHook_StartTouch, StartTouch);
	}
}

static void StartTouch(int entity, int other)
{
	SF2_ProjectileArrow projectile = SF2_ProjectileArrow(entity);

	if (other == 0)
	{
		RemoveEntity(projectile.index);
		return;
	}

	bool hit = true;
	SF2_BasePlayer otherPlayer = SF2_BasePlayer(other);
	if (otherPlayer.IsValid)
	{
		if (otherPlayer.IsInGhostMode || (otherPlayer.IsProxy && !projectile.AttackWaiters))
		{
			return;
		}
	}
	else
	{
		int hitIndex = NPCGetFromEntIndex(other);
		if (hitIndex != -1)
		{
			hit = false;
		}
	}

	if (projectile.GetPropEnt(Prop_Send, "m_hOwnerEntity") == other)
	{
		hit = false;
	}

	if (SF2_ProjectileBase(other).IsValid())
	{
		hit = false;
	}

	if (SF2_BasePlayer(other).IsValid)
	{
		hit = true;
	}

	if (hit)
	{
		int owner = projectile.GetPropEnt(Prop_Send, "m_hOwnerEntity");
		int flags = DMG_BULLET;
		float pos[3];
		projectile.GetAbsOrigin(pos);
		if (projectile.IsCrits)
		{
			flags |= DMG_ACID;
		}
		SF2_BasePlayer player = SF2_BasePlayer(other);
		if (player.IsValid)
		{
			if (!projectile.AttackWaiters && player.IsEliminated)
			{
				return;
			}

			player.TakeDamage(_, !IsValidEntity(owner) ? projectile.index : owner, !IsValidEntity(owner) ? projectile.index : owner, projectile.Damage, flags, _, _, pos);
			Call_StartForward(g_OnPlayerDamagedByProjectilePFwd);
			Call_PushCell(player);
			Call_PushCell(projectile);
			Call_Finish();
		}
		else
		{
			SDKHooks_TakeDamage(other, !IsValidEntity(owner) ? projectile.index : owner, !IsValidEntity(owner) ? projectile.index : owner, projectile.Damage, flags, _, _, pos);
		}
		EmitSoundToAll(projectile.GetImpactSound(), projectile.index, SNDCHAN_ITEM, SNDLEVEL_SCREAMING);
		RemoveEntity(projectile.index);
	}
}