//	Rare-Animation-Controller is a SourcePawn plugin (.sp) that tweaks the usage of rare weapon animations.
//	Copyright (C) 2021  Natanel 'LuqS' Shitrit & Omer 'KoNLiG' Ben Tzion.

//	This program is free software: you can redistribute it and/or modify
//	it under the terms of the GNU General Public License as published by
//	the Free Software Foundation, either version 3 of the License, or
//	(at your option) any later version.

//	This program is distributed in the hope that it will be useful,
//	but WITHOUT ANY WARRANTY; without even the implied warranty of
//	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//	GNU General Public License for more details.

//	You should have received a copy of the GNU General Public License
//	along with this program.  If not, see <https://www.gnu.org/licenses/>.

#include <sourcemod>
#include <sdkhooks>
#include <anymap>
#include <studio_hdr>
#include <RareAnimationController>

#pragma newdecls required
#pragma semicolon 1

// Offset of the lookat member.
#define LOOKAT_OFFSET 5

// Rare sequence struct.
enum struct RareSequences
{
    int index[RARE_SEQUENCE_MAX];
    float duration[RARE_SEQUENCE_MAX];
}

// All weapons rare sequences.
AnyMap g_RareSequences;

// Forward when animations gets tweaked.
GlobalForward g_OnRareAnimation;

public Plugin myinfo = 
{
    name = "[CS:GO] Rare Animation Controller", 
    author = "Natanel 'LuqS', KoNLiG", 
    description = "Tweaks the usage of rare weapon animations.", 
    version = "1.0.5", 
    url = "https://github.com/Natanel-Shitrit/Rare-Animation-Controller"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    // Lock the use of this plugin for CS:GO only.
    if (GetEngineVersion() != Engine_CSGO)
    {
        strcopy(error, err_max, "This plugin was made for use with CS:GO only.");
        return APLRes_Failure;
    }
    
    g_OnRareAnimation = new GlobalForward(
        "OnRareAnimation", 
        ET_Event,
        Param_Cell, // client
        Param_Cell, // weapon
        Param_Cell, // sequence_type
        Param_Cell, // sequence_index
        Param_Float // duration
    );
    
    RegPluginLibrary("RareAnimationController");
    
    return APLRes_Success;
}

Action Call_OnRareAnimation(int client, int weapon, int sequence_type, int sequence_index, float duration)
{
    Action result;
    
    Call_StartForward(g_OnRareAnimation);
    Call_PushCell(client);
    Call_PushCell(weapon);
    Call_PushCell(sequence_type);
    Call_PushCell(sequence_index);
    Call_PushFloat(duration);
    Call_Finish(result);
    
    return result;
}

public void OnPluginStart()
{
    // Hook '+lookatweapon' command.
    AddCommandListener(Listener_LookAtWeapon, "+lookatweapon");
    
    // Stores each weapon rare inspect sequence index by it's definition index.
    g_RareSequences = new AnyMap();
    
    // Late-Load for inspect hooking.
    for (int current_client = 1; current_client <= MaxClients; current_client++)
    {
        if (IsClientInGame(current_client))
        {
            OnClientPutInServer(current_client);
        }
    }
}

public void OnClientPutInServer(int client)
{
    // Hook weapon switch to change animation.
    SDKHook(client, SDKHook_WeaponSwitchPost, Hook_OnWeaponSwitch);
}

void Hook_OnWeaponSwitch(int client, int weapon)
{
    // Load weapon sequences if not already loaded.
    int predicted_viewmodel;
    RareSequences rare_sequences;
    if (!LoadWeaponSequences(client, rare_sequences, predicted_viewmodel, weapon) || rare_sequences.index[RARE_SEQUENCE_DRAW] == -1)
    {
        return;
    }
    
    // Call animation forward to allow plugins to block it.
    if (Call_OnRareAnimation(client, weapon, RARE_SEQUENCE_DRAW, rare_sequences.index[RARE_SEQUENCE_DRAW], rare_sequences.duration[RARE_SEQUENCE_DRAW]) >= Plugin_Handled)
    {
        return;
    }
    
    // Set rare animation.
    SetEntProp(predicted_viewmodel, Prop_Send, "m_nSequence", rare_sequences.index[RARE_SEQUENCE_DRAW]);
    
    // Fix the animation duration.
    float next_attack = GetGameTime() + rare_sequences.duration[RARE_SEQUENCE_DRAW];
    if (GetEntPropFloat(client, Prop_Send, "m_flNextAttack") < next_attack)
    {
        SetEntPropFloat(client, Prop_Send, "m_flNextAttack", next_attack);
    }
}

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int switch_weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
    static int old_buttons[MAXPLAYERS + 1];
    
    // Apply rare sequence
    if (!(old_buttons[client] & IN_RELOAD) && (buttons & IN_RELOAD))
    {
        // Load weapon sequences if not already loaded.
        int predicted_viewmodel, weapon;
        RareSequences rare_sequences;
        if (!LoadWeaponSequences(client, rare_sequences, predicted_viewmodel, weapon) || rare_sequences.index[RARE_SEQUENCE_IDLE] == -1)
        {
            return;
        }
        
        // Call animation forward to allow plugins to block it.
        if (Call_OnRareAnimation(client, weapon, RARE_SEQUENCE_IDLE, rare_sequences.index[RARE_SEQUENCE_IDLE], rare_sequences.duration[RARE_SEQUENCE_IDLE]) >= Plugin_Handled)
        {
            return;
        }
        
        // Set rare animation.
        SetEntProp(predicted_viewmodel, Prop_Send, "m_nSequence", rare_sequences.index[RARE_SEQUENCE_IDLE]);
        
        // Fix the animation duration.
        SetEntPropFloat(weapon, Prop_Data, "m_flTimeWeaponIdle", GetGameTime() + rare_sequences.duration[RARE_SEQUENCE_IDLE]);
    }
    
    // Save old buttons.
    old_buttons[client] = buttons;
}

Action Listener_LookAtWeapon(int client, const char[] command, int argc)
{
    if (!IsClientInGame(client))
    {
        return Plugin_Continue;
    }

    // Load weapon sequences if not already loaded.
    int predicted_viewmodel, weapon;
    RareSequences rare_sequences;
    if (!LoadWeaponSequences(client, rare_sequences, predicted_viewmodel, weapon) || rare_sequences.index[RARE_SEQUENCE_INSPECT] == -1)
    {
        return Plugin_Continue;
    }
    
    // Call animation forward to allow plugins to block it.
    if (Call_OnRareAnimation(client, weapon, RARE_SEQUENCE_INSPECT, rare_sequences.index[RARE_SEQUENCE_INSPECT], rare_sequences.duration[RARE_SEQUENCE_INSPECT]) >= Plugin_Handled)
    {
        return Plugin_Continue;
    }
    
    // If the client is available for sequence changes, apply the rare inspect sequence. 
    if (!GetEntProp(client, Prop_Send, "m_bIsLookingAtWeapon", 1))
    {
        return Plugin_Continue;
    }
    
    // Set rare animation.
    SetEntProp(predicted_viewmodel, Prop_Send, "m_nSequence", rare_sequences.index[RARE_SEQUENCE_INSPECT]);
    
    // Fix the animation duration:
    
    // Find offset.
    static int m_flLookWeaponEndTimeOffset;
    if (!m_flLookWeaponEndTimeOffset)
    {
        m_flLookWeaponEndTimeOffset = GetEntSendPropOffs(client, "m_bIsHoldingLookAtWeapon", true) + LOOKAT_OFFSET;
    }
    
    // Store new animation duration.
    SetEntData(client, m_flLookWeaponEndTimeOffset, GetGameTime() + rare_sequences.duration[RARE_SEQUENCE_INSPECT]);

    return Plugin_Continue;
}

bool LoadWeaponSequences(int client, RareSequences rare_sequences, int &predicted_viewmodel, int &weapon)
{
    // Get client predicted viewmodel.
    // Get the client active weapon by 'predicted_viewmodel'.
    if ((predicted_viewmodel = GetEntPropEnt(client, Prop_Send, "m_hViewModel")) == -1 || (!weapon && (weapon = GetEntPropEnt(predicted_viewmodel, Prop_Send, "m_hWeapon")) == -1))
    {
        return false;
    }
    
    int weapon_defindex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
    // If the weapon sequences already loaded, no need to continue.
    if (g_RareSequences.GetArray(weapon_defindex, rare_sequences, sizeof(rare_sequences)))
    {
        return true;
    }
    
    // Get entity StudioHdr (and make sure it's valid).
    StudioHdr studio_hdr = GetEntityStudioHdr(weapon);
    if (studio_hdr == NULL_STUDIO_HDR)
    {
        return false;
    }
    
    // This check covers knives animations and redirects us to the right StudioHdr data.
    // Knives animations and sequences deperated to store in different file named (in most cases) 'Knife View Model + _anim.mdl'.
    // Here 'IncludeModel' methodmap becomes a good use for us.
    if (!studio_hdr.numlocalseq && studio_hdr.numincludemodels)
    {
        char include_model[PLATFORM_MAX_PATH];
        studio_hdr.GetIncludeModel(0).GetName(include_model, sizeof(include_model));
        
        if ((studio_hdr = StudioHdr(include_model)) == NULL_STUDIO_HDR || !studio_hdr.numlocalseq)
        {
            return false;
        }
    }
    
    // Prepare variables for the loop(s).
    Animation animation;
    Sequence sequence;
    char sequence_name[32];
    int num_sequecnes[RARE_SEQUENCE_MAX];
    
    // Loop through all the model sequences and find the rare one.
    for (int current_sequence, min_actweights[RARE_SEQUENCE_MAX] = { -1, ... }, sequence_type; current_sequence < studio_hdr.numlocalseq; current_sequence++)
    {
        // Get current sequence and the name of the sequence.
        sequence = studio_hdr.GetSequence(current_sequence);
        sequence.GetLabelName(sequence_name, sizeof(sequence_name));
        
        // Find sequence type.
        sequence_type = StrContains(sequence_name, "draw") != -1 ? RARE_SEQUENCE_DRAW : 
                        StrContains(sequence_name, "idle") != -1 ? RARE_SEQUENCE_IDLE : 
                        StrContains(sequence_name, "lookat") != -1 ? RARE_SEQUENCE_INSPECT : RARE_SEQUENCE_NONE;
        
        // Skip unrelated sequences, or sequences without act weight.
        if (sequence_type == RARE_SEQUENCE_NONE || sequence.actweight <= 0)
        {
            continue;
        }
        
        // Find the rarest sequence of all.
        if (min_actweights[sequence_type] == -1 || sequence.actweight < min_actweights[sequence_type])
        {
            rare_sequences.index[sequence_type] = current_sequence;
            
            min_actweights[sequence_type] = sequence.actweight;
        }
        // Rarest sequence is the same weight as the current one so it's not rare.
        else if (sequence.actweight == min_actweights[sequence_type])
        {
            rare_sequences.index[sequence_type] = -1;
        }
        
        // Keep track of the number of sequences of each type.
        num_sequecnes[sequence_type]++;
    }
    
    // Loop through all sequences types and save rarest ones.
    for (int current_sequence; current_sequence < RARE_SEQUENCE_MAX; current_sequence++)
    {
        // If there is only 1 sequence it can't be rare.
        if (num_sequecnes[current_sequence] < 2)
        {
            rare_sequences.index[current_sequence] = -1;
        }
        
        // Check there is a rare animation.
        if (rare_sequences.index[current_sequence] != -1)
        {
            // Get sequence object.
            sequence = studio_hdr.GetSequence(rare_sequences.index[current_sequence]);
            
            // Load animation index of the sequece.
            animation = studio_hdr.GetAnimation(LoadFromAddress(view_as<Address>(sequence) + view_as<Address>(sequence.animindexindex), NumberType_Int32));
            
            // Save duration of animation with formula: number of frames in the animation / frames per second.
            rare_sequences.duration[current_sequence] = float(animation.numframes) / animation.fps;
        }
    }
    
    // Save all data about animation in the weapon defindex.
    return g_RareSequences.SetArray(weapon_defindex, rare_sequences, sizeof(rare_sequences));
} 
