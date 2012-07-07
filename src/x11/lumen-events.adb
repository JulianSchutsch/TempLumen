
-- Lumen.Events -- Manage input events in Lumen windows
--
-- Chip Richards, NiEstu, Phoenix AZ, Spring 2010

-- This code is covered by the ISC License:
--
-- Copyright © 2010, NiEstu
--
-- Permission to use, copy, modify, and/or distribute this software for any
-- purpose with or without fee is hereby granted, provided that the above
-- copyright notice and this permission notice appear in all copies.
--
-- The software is provided "as is" and the author disclaims all warranties
-- with regard to this software including all implied warranties of
-- merchantability and fitness. In no event shall the author be liable for any
-- special, direct, indirect, or consequential damages or any damages
-- whatsoever resulting from loss of use, data or profits, whether in an
-- action of contract, negligence or other tortious action, arising out of or
-- in connection with the use or performance of this software.

-- Environment
with System;

with Lumen.Events.Key_Translate;
with Lumen.Window;
with X11; use X11;

package body Lumen.Events is

   -- Xlib stuff needed for our window info record

   -- Convert a Key_Symbol into a Latin-1 character; raises Not_Character if
   -- it's not possible.  Character'Val is simpler.
   function To_Character (Symbol : in Key_Symbol) return Character is
   begin  -- To_Character
      if Symbol not in Key_Symbol (Character'Pos (Character'First)) .. Key_Symbol (Character'Pos (Character'Last)) then
         raise Not_Character;
      end if;

      return Character'Val (Natural (Symbol));
   end To_Character;

   ---------------------------------------------------------------------------

   -- Convert a Key_Symbol into a UTF-8 encoded string; raises Not_Character
   -- if it's not possible.  Really only useful for Latin-1 hibit chars, but
   -- works for all Latin-1 chars.
   function To_UTF_8 (Symbol : in Key_Symbol) return String is

      Result : String (1 .. 2);  -- as big as we can encode

   begin  -- To_UTF_8
      if Symbol not in Key_Symbol (Character'Pos (Character'First)) .. Key_Symbol (Character'Pos (Character'Last)) then
         raise Not_Character;
      end if;

      if Symbol < 16#7F# then
         -- 7-bit characters just pass through unchanged
         Result (1) := Character'Val (Symbol);
         return Result (1 .. 1);
      else
         -- 8-bit characters are encoded in two bytes
         Result (1) := Character'Val (16#C0# + (Symbol  /  2 ** 6));
         Result (2) := Character'Val (16#80# + (Symbol rem 2 ** 6));
         return Result;
      end if;
   end To_UTF_8;

   ---------------------------------------------------------------------------

   -- Convert a normal Latin-1 character to a Key_Symbol
   function To_Symbol (Char : in Character) return Key_Symbol is
   begin  -- To_Symbol
      return Key_Symbol (Character'Pos (Char));
   end To_Symbol;

   ---------------------------------------------------------------------------

   -- Returns the number of events that are waiting in the event queue.
   -- Useful for more complex event loops.
   function Pending (Win : Window_Handle) return Natural is

      XWin : X11Window_Handle:=X11Window_Handle(Win);

      function X_Pending (Display : Display_Pointer) return Natural;
      pragma Import (C, X_Pending, "XPending");

   begin  -- Pending
      return X_Pending (XWin.Display);
   end Pending;

   ---------------------------------------------------------------------------

   -- Retrieve the next input event from the queue and return it
   function Next_Event (Win       : in Window_Handle;
                        Translate : in Boolean := True) return Event_Data is

      XWin : X11Window_Handle:=X11Window_Handle(Win);

      ------------------------------------------------------------------------

      -- Convert an X modifier mask into a Lumen modifier set
      function Modifier_Mask_To_Set (Mask : Modifier_Mask) return Modifier_Set is
      begin  -- Modifier_Mask_To_Set
         return (
                 Mod_Shift    => (Mask and Shift_Mask)    /= 0,
                 Mod_Lock     => (Mask and Lock_Mask)     /= 0,
                 Mod_Control  => (Mask and Control_Mask)  /= 0,
                 Mod_1        => (Mask and Mod_1_Mask)    /= 0,
                 Mod_2        => (Mask and Mod_2_Mask)    /= 0,
                 Mod_3        => (Mask and Mod_3_Mask)    /= 0,
                 Mod_4        => (Mask and Mod_4_Mask)    /= 0,
                 Mod_5        => (Mask and Mod_5_Mask)    /= 0,
                 Mod_Button_1 => (Mask and Button_1_Mask) /= 0,
                 Mod_Button_2 => (Mask and Button_2_Mask) /= 0,
                 Mod_Button_3 => (Mask and Button_3_Mask) /= 0,
                 Mod_Button_4 => (Mask and Button_4_Mask) /= 0,
                 Mod_Button_5 => (Mask and Button_5_Mask) /= 0
                );
      end Modifier_Mask_To_Set;

      ------------------------------------------------------------------------

      X_Event   : X_Event_Data;
      Buffer    : String (1 .. 1);
      Got       : Natural;
      Key_Mods  : Modifier_Set;
      X_Keysym  : Key_Symbol;
      Key_Value : Key_Symbol;
      Key_Type  : Key_Category;

      ------------------------------------------------------------------------

   begin  -- Next_Event

      -- Get the event from the X server
      X_Next_Event (XWin.Display, X_Event'Address);

      -- Guard against pathological X servers
      if not X_Event.X_Event_Type'Valid then
         return (Which => Unknown_Event);
      end if;

      -- Based on the event type, transfer and convert the event data
      case X_Event.X_Event_Type is

         when X_Key_Press | X_Key_Release =>
            Key_Mods := Modifier_Mask_To_Set (X_Event.Key_State);

            -- If caller wants keycode translation, ask X for the value, since
            -- he's the only one who knows
            if Translate then
               Got := X_Lookup_String (X_Event'Address, Buffer'Address, 1, X_Keysym'Address, System.Null_Address);

               -- If X translated it to ASCII for us, just use that
               if Got > 0 then
                  Key_Value := Character'Pos (Buffer (Buffer'First));

                  -- See if it's a normal control char or DEL, else it's a graphic char
                  if Buffer (Buffer'First) < ' ' or Buffer (Buffer'First) = Character'Val (16#7F#) then
                     Key_Type := Key_Control;
                  else
                     Key_Type := Key_Graphic;
                  end if;
               else

                  -- Not ASCII, do our own translation
                  Key_Translate.Keysym_To_Symbol (X_Keysym, Key_Mods, Key_Value, Key_Type);
               end if;
            else

               -- Caller didn't want keycode translation, the bum
               Key_Type := Key_Not_Translated;
            end if;

            -- Now decide whether it was a press or a release, and return the value
            if X_Event.X_Event_Type = X_Key_Press then
               return (Which     => Key_Press,
                       Key_Data  => (X         => X_Event.Key_X,
                                     Y         => X_Event.Key_Y,
                                     Abs_X     => X_Event.Key_Root_X,
                                     Abs_Y     => X_Event.Key_Root_Y,
                                     Modifiers => Key_Mods,
                                     Key_Code  => Raw_Keycode (X_Event.Key_Code),
                                     Key_Type  => Key_Type,
                                     Key       => Key_Value));
            else
               return (Which     => Key_Release,
                       Key_Data  => (X         => X_Event.Key_X,
                                     Y         => X_Event.Key_Y,
                                     Abs_X     => X_Event.Key_Root_X,
                                     Abs_Y     => X_Event.Key_Root_Y,
                                     Modifiers => Key_Mods,
                                     Key_Code  => Raw_Keycode (X_Event.Key_Code),
                                     Key_Type  => Key_Type,
                                     Key       => Key_Value));
            end if;

         when X_Button_Press =>
            return (Which        => Button_Press,
                    Button_Data  => (X         => X_Event.Btn_X,
                                     Y         => X_Event.Btn_Y,
                                     Abs_X     => X_Event.Btn_Root_X,
                                     Abs_Y     => X_Event.Btn_Root_Y,
                                     Modifiers => Modifier_Mask_To_Set (X_Event.Btn_State),
                                     Changed   => Button_Enum'Val (X_Event.Btn_Code - 1)));

         when X_Button_Release =>
            return (Which        => Button_Release,
                    Button_Data  => (X         => X_Event.Btn_X,
                                     Y         => X_Event.Btn_Y,
                                     Abs_X     => X_Event.Btn_Root_X,
                                     Abs_Y     => X_Event.Btn_Root_Y,
                                     Modifiers => Modifier_Mask_To_Set (X_Event.Btn_State),
                                     Changed   => Button_Enum'Val (X_Event.Btn_Code - 1)));

         when X_Motion_Notify =>
            return (Which       => Pointer_Motion,
                    Motion_Data => (X         => X_Event.Mov_X,
                                    Y         => X_Event.Mov_Y,
                                    Abs_X     => X_Event.Mov_Root_X,
                                    Abs_Y     => X_Event.Mov_Root_Y,
                                    Modifiers => Modifier_Mask_To_Set (X_Event.Mov_State)));

         when X_Enter_Notify =>
            return (Which         => Enter_Window,
                    Crossing_Data => (X         => X_Event.Xng_X,
                                      Y         => X_Event.Xng_Y,
                                      Abs_X     => X_Event.Xng_Root_X,
                                      Abs_Y     => X_Event.Xng_Root_Y));

         when X_Leave_Notify =>
            return (Which     => Leave_Window,
                    Crossing_Data => (X         => X_Event.Xng_X,
                                      Y         => X_Event.Xng_Y,
                                      Abs_X     => X_Event.Xng_Root_X,
                                      Abs_Y     => X_Event.Xng_Root_Y));

         when X_Focus_In =>
            return (Which => Focus_In);

         when X_Focus_Out =>
            return (Which => Focus_Out);

         when X_Expose =>
            return (Which       => Exposed,
                    Expose_Data => (X         => X_Event.Xps_X,
                                    Y         => X_Event.Xps_Y,
                                    Width     => X_Event.Xps_Width,
                                    Height    => X_Event.Xps_Height,
                                    Count     => X_Event.Xps_Count));

         when X_Unmap_Notify =>
            return (Which       => Hidden);

         when X_Map_Notify =>
            -- Fake up a "whole window exposed" event
            return (Which       => Exposed,
                    Expose_Data => (X         => 0,
                                    Y         => 0,
                                    Width     => Win.Width,
                                    Height    => Win.Height,
                                    Count     => 0));

         when X_Configure_Notify =>
            if X_Event.Cfg_Width /= Win.Width or X_Event.Cfg_Height /= Win.Height then
               Win.Width  := X_Event.Cfg_Width;
               Win.Height := X_Event.Cfg_Height;
               return (Which       => Resized,
                       Resize_Data => (Width     => X_Event.Cfg_Width,
                                       Height    => X_Event.Cfg_Height));
            else
               -- Fake up a "whole window exposed" event
               return (Which       => Exposed,
                       Expose_Data => (X         => 0,
                                       Y         => 0,
                                       Width     => X_Event.Cfg_Width,
                                       Height    => X_Event.Cfg_Height,
                                       Count     => 0));
            end if;

         when X_Client_Message =>
            declare
               use type Atom;
            begin
               if X_Event.Msg_Value = Delete_Window_Atom then
                  return (Which => Close_Window);
               else
                  return (Which => Unknown_Event);
               end if;
            end;

         when others =>
            return (Which => Unknown_Event);

      end case;

   end Next_Event;

   ---------------------------------------------------------------------------

   -- Simple event loop with a single callback
   procedure Receive_Events (Win       : in Window_Handle;
                             Call      : in Event_Callback;
                             Translate : in Boolean := True) is
   begin  -- Receive_Events

      -- Get events and pass them to the callback
      Win.Looping := True;
      while Win.Looping loop
         Call (Next_Event (Win, Translate));
      end loop;
   end Receive_Events;

   ---------------------------------------------------------------------------

   -- Simple event loop with multiple callbacks based on event type
   procedure Select_Events (Win       : in Window_Handle;
                            Calls     : in Event_Callback_Table;
                            Translate : in Boolean := True) is

      Event : Event_Data;

   begin  -- Select_Events

      -- Get events and pass them to the selected callback, if there is one
      Win.Looping := True;
      while Win.Looping loop
         Event := Next_Event (Win, Translate);

         if Calls (Event.Which) /= No_Callback then
            Calls (Event.Which) (Event);
         end if;
      end loop;
   end Select_Events;

   ---------------------------------------------------------------------------

   -- Terminate internal event loops, causes Receive_Events and Select_Events to return
   procedure End_Events (Win : in Window_Handle) is
   begin  -- End_Events
      Win.Looping := False;  -- terminates internal event loop
   end End_Events;

   ---------------------------------------------------------------------------

   procedure Process (Win : in Window_Handle) is
   begin
      null;
   end Process;

   ---------------------------------------------------------------------------

end Lumen.Events;