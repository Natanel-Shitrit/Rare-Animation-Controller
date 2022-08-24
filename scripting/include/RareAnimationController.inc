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

#if defined _rare_animation_controller_included
 #endinput
#endif
#define _rare_animation_controller_included

enum
{
    RARE_SEQUENCE_DRAW, 
    RARE_SEQUENCE_IDLE, 
    RARE_SEQUENCE_INSPECT, 
    RARE_SEQUENCE_MAX, 
    RARE_SEQUENCE_NONE
}

/**
 * Retrieves the rare sequence index of an econ item.
 * 
 * @param definition_index	Item definition index.
 * @param sequence_type     Sequence type, see the enum above.
 * 
 * @return 					Sequence index, or -1 if no sequences were loaded for the given definition index.		
 * @error					Invalid sequence type.
 */
int GetRareAnimationIndex(int definition_index, int sequence_type);

/**
 * Retrieves the rare sequence duration of an econ item.
 * 
 * @param definition_index	Item definition index.
 * @param sequence_type     Sequence type, see the enum above.
 * 
 * @return 					Animation duration (in seconds), or 0.0 if no sequences were loaded for the given definition index.
 * @error					Invalid item definition index or invalid sequence type.
 */
float GetRareAnimationDuration(int definition_index, int sequence_type);

/**
 * Called before a rare animation sequence is applied.
 *
 * @param client            Client index.	
 * @param weapon            Weapon entity index.
 * @param sequence_type     Sequence type, see the enum above.
 * @param sequence_index    New applied sequence index.
 * @param duration          Duration of the new sequence.
 *
 * @return                  Plugin_Handled or higher to block the sequence change.
 */
forward Action OnRareAnimation(int client, int weapon, int sequence_type, int sequence_index, float duration);

#if !defined REQUIRE_PLUGIN
public void __pl_rare_animation_controller_SetNTVOptional()
{
    MarkNativeAsOptional("GetRareAnimationIndex");
    MarkNativeAsOptional("GetRareAnimationDuration");
}
#endif

public SharedPlugin __pl_rare_animation_controller = 
{
    name = "RareAnimationController", 
    file = "RareAnimationController.smx", 
#if defined REQUIRE_PLUGIN
    required = 1, 
#else
    required = 0, 
#endif
}; 