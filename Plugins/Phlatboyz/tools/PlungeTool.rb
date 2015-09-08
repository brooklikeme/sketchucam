#plungeTool and CSinkTool
require 'sketchup.rb'
#require 'Phlatboyz/Constants.rb'
require 'Phlatboyz/Tools/PlungeCut.rb'

module PhlatScript

  class PlungeTool < PhlatTool
    @depth = 100
    @dia = 0
    @keyflag = 0
    
    def initialize
       super()
       @hspace = 1
       @vspace = 1
       @hcount = 0
       @vcount = 0
       @keyflag = 0 
       @dia = 0.0
    end
    
    def reset(view)
#      puts "PlungeTool reset"
      Sketchup.vcb_label = "Plunge Depth %"
      Sketchup.vcb_value = PhlatScript.cutFactor
      @depth = PhlatScript.cutFactor
      @dia = 0.0
      super
    end

    def onMouseMove(flags, x, y, view)
      if @ip.pick(view, x, y)
        view.invalidate
      end
    end
    
    def getPattern
      if ((@hcount == 0) || (@vcount == 0))
         if PhlatScript.isMetric
            @hspace = @vspace = 7.mm
         else
            @hspace = @vspace = 0.25.inch
         end
         @hcount = @vcount = 2
      end
      # prompts
      prompts=['Horiz Spacing ',
               'Vert Spacing  ',
               'Horiz Count ',
               'Vert Count  ' ]

      defaults=[
         Sketchup.format_length(@hspace),
         Sketchup.format_length(@vspace),
         @hcount,
         @vcount            ]
      # dropdown options can be added here
      list=["",
         "",
         "",
         ""                ]

      input = UI.inputbox(prompts, defaults, list, 'Drill Hole Pattern')
      # input is nil if user cancelled
      if (input)
         @hspace = Sketchup.parse_length(input[0])
         @vspace = Sketchup.parse_length(input[1])
         @hcount = input[2].to_i            
         @vcount = input[3].to_i            
         return (@hcount > 0) && (@vcount > 0) && (@vspace > 0) && (@hspace > 0)
      else
         return false
      end
    end

   def getDia()
      res = UI.inputbox(["Enter Hole Diameter in model units"],[0.to_s],"Bored Hole Diameter entry")
      begin
         dia = Sketchup.parse_length(res[0])
#         .to_f
#         if PhlatScript.isMetric
#            dia = dia.mm # convert to inch
#         end

         if (dia < PhlatScript.bitDiameter)
            dia = PhlatScript.bitDiameter
         end
      rescue  Exception => e
         dia = 0
         UI.messagebox "Exception in PlungeTool:getDia "+$! + e.backtrace.to_s
      end         
      return dia
    end

    def onLButtonDown(flags, x, y, view)
#      puts "flags " + sprintf('%08b',flags)
#      if (@keyflag == 2)
      if ((flags & 32) == 32) || ((flags & 8) == 8) # ALT button or CTRL button, alt does not work in Ubuntu
#         puts "placing hole pattern"
         @dia = 0
         if ((flags & 4) == 4)  # want big hole too, SHIFT button down
            @dia = getDia()
#            puts "dia #{@dia}"
         end
         #get params
         if getPattern()
            #place hole pattern, bottom left is clicked point
#            puts "#{@ip.position} #{@hspace}"
            np = @ip.position
            ccnt = 1
            for v in 0..(@vcount - 1)
#               puts "v #{v}"
               for h in 0..(@hcount - 1)
#                  puts "  h #{h}"
                  np.x = @ip.position.x + h * @hspace
                  np.y = @ip.position.y + v * @vspace
#                  puts "#{np}"
                  PlungeCut.cut(np, @depth, @dia, ccnt)
                  ccnt += 1
               end
            end
         end
      else
#         if (@keyflag == 1)
         if ((flags & 4) == 4) # shift
            #prompt for diameter
            @dia = getDia()
            if (@dia > PhlatScript.bitDiameter)
               PlungeCut.cut(@ip.position, @depth, @dia)
               @dia = 0
            else
               puts "Ignored dia <= bitdiameter"
            end
         else
           PlungeCut.cut(@ip.position, @depth, 0)
         end
      end
      reset(view)
    end

    def draw(view)
      PlungeCut.preview(view, @ip.position)
    end

    def cut_class
      return PlungeCut
    end

    def statusText
      return "Select plunge point, [SHIFT] for large hole, set depth in VCB, [ALT] for hole pattern"
    end

    def enableVCB?
      return true
    end
# get user entered number for plunge depth as percentage of material thickness
    def onUserText(text, view)
      parsed = text.to_f #do not use parse_length function
      if (parsed < 1)
        parsed = 1
      end
      if (parsed > (2*PhlatScript.cutFactor))
        parsed = 2*PhlatScript.cutFactor
      end
      if (!parsed.nil?)
        @depth = parsed
        Sketchup::set_status_text("#{@depth.to_s}%", SB_VCB_VALUE)
#        puts "New Plunge Depth " + @depth.to_s
      end
    end

#swarfer: detect keys
    def onKeyDown(key, repeat, flags, view)
       if (key == VK_SHIFT)
          @keyflag = 1
       end
       if (key == VK_ALT)
          @keyflag = 2
       end
    end

    def onKeyUp(key, repeat, flags, view)
       if ((key = VK_SHIFT) || (key = VK_ALT))
          @keyflag = 0
       end
    end


  end
#-----------------------------------------------------------------------------------
   class CsinkTool < PlungeTool

   def initialize
       super()
       @cdia = 0.0
       @angle = 0.0
       @cdepth = PhlatScript.materialThickness / 2
       @mode = 'CounterSink'
   end
   
   def reset(view)
      Sketchup.vcb_label = "Plunge Depth %"
      Sketchup.vcb_value = PhlatScript.cutFactor
      @depth = PhlatScript.cutFactor
   end

   def getCounterSink
      # prompts
      prompts=['CounterSink or CounterBore?',
               'Counter sink/bore diam ( > bit!)',
               'Counter sink Angle (70..179)',
               'CounterBore depth ( < material thickness)',
               'Hole Diam (0 for current bit)' 
               ]
      if (@angle < 70.0)
         @angle = 90.0
      end
      #puts @cdia
      @cdia = (@cdia == 0.0) ? PhlatScript.bitDiameter * 2 : @cdia
      #puts @cdia
      defaults=[
         @mode,
         Sketchup.format_length(@cdia),
         @angle.to_s,
         Sketchup.format_length(@cdepth),
         Sketchup.format_length(@dia)
         ]
      # dropdown options can be added here
      list=["CounterSink|CounterBore",
         "",
         "",
         "",
         ""                ]

      input = UI.inputbox(prompts, defaults, list, 'Counter Sink options')
      # input is nil if user cancelled
      if (input)
         @mode = input[0]
         if (input[0] == 'CounterSink')
            @cdia = Sketchup.parse_length(input[1])
            @angle = input[2].to_f
            @angle = 70.0 if (@angle < 70.0)
            @angle = 179.0 if (@angle > 179.0)
            @dia = Sketchup.parse_length(input[4])
            if (@dia < PhlatScript.bitDiameter)
               @dia = 0
            end
            return (@cdia > PhlatScript.bitDiameter) && (@cdia > @dia) && (@angle >= 70)
         else
            @cdia = Sketchup.parse_length(input[1])
            @angle = -90  #indicates counterbore
            @cdepth = Sketchup.parse_length(input[3])
            #puts @cdepth.to_mm
            @depth = PhlatScript.cutFactor
            @dia = Sketchup.parse_length(input[4])
            if (@dia < PhlatScript.bitDiameter)
               @dia = 0
            end
            return (@cdia > PhlatScript.bitDiameter) && (@cdia > @dia) && (@cdepth < PhlatScript.materialThickness)
         end
      else
         return false
      end
    end
    
   def activate
      super
      if getCounterSink 
      else
         puts "getcountersink cancelled"
         @dia = @cdia = 0
         #deselect the tool?
         Sketchup.active_model.select_tool(nil)
      end
   end

#countersink and bore version
   def onLButtonDown(flags, x, y, view)
#      puts "flags " + sprintf('%08b',flags)
      if ((flags & 32) == 32) || ((flags & 8) == 8) # ALT button or CTRL button, alt does not work in Ubuntu
#         puts "placing hole pattern"
         
         if ((flags & 4) == 4)  # want big hole too, SHIFT button down
            @dia = getDia()
            @dia = @dia < @cdia ? @dia :  0.0
#            puts "dia #{@dia}"
         end
         #get params
         if getPattern()
            #place hole pattern, bottom left is clicked point
#            puts "#{@ip.position} #{@hspace}"
            np = @ip.position
            ccnt = 1
            for v in 0..(@vcount - 1)
#               puts "v #{v}"
               for h in 0..(@hcount - 1)
#                  puts "  h #{h}"
                  np.x = @ip.position.x + h * @hspace
                  np.y = @ip.position.y + v * @vspace
#                  puts "#{np}"

                  #PlungeCut.cut(np, @depth, @dia, ccnt,@angle, @cdia)
                  if @mode == 'CounterSink'
                     PlungeCut.cut(np, @depth, @dia, ccnt,@angle,@cdia)
                  else
                     PlungeCut.cut(np, @depth, @dia, ccnt,@angle,@cdia, @cdepth)            
                  end
                  
                  ccnt += 1
               end
            end
         end
      else
#         if (@keyflag == 1)
         if ((flags & 4) == 4) # shift
            #prompt for diameter
            @dia = getDia()
            @dia = @dia < @cdia ? @dia :  PhlatScript.bitDiameter + 0.1
            if (@dia > PhlatScript.bitDiameter)
               if @mode == 'CounterSink'
                  PlungeCut.cut(@ip.position, @depth, @dia, 0,@angle,@cdia)
               else # mode is CounterBore
                  PlungeCut.cut(@ip.position, @depth, @dia, 0,@angle,@cdia, @cdepth)            
               end
            else
               puts "Ignored dia <= bitdiameter"
            end
         else
            if @mode == 'CounterSink'
               PlungeCut.cut(@ip.position, @depth, @dia, 0,@angle,@cdia)
            else
               PlungeCut.cut(@ip.position, @depth, @dia, 0,@angle,@cdia, @cdepth)            
            end
         end
      end
      reset(view)
   end
   
   def statusText
      return "Select CounterSink plunge point, [SHIFT] for large hole, [ALT] for hole pattern"
   end

   end # class

#-----------------------------------------------------------------------------------
   class CboreTool < PlungeTool

   def initialize
       super()
       @cdia = 0.0
       @angle = 0.0
       @cdepth = PhlatScript.materialThickness / 2
   end
   
   def reset(view)
      Sketchup.vcb_label = "Plunge Depth %"
      Sketchup.vcb_value = PhlatScript.cutFactor
      @depth = PhlatScript.cutFactor
   end

   def getCounterBore
      # prompts
      prompts=['Counter bore diam ( > bit!)',
               'Counter bore depth ( < material)',
               'Hole Diam (0 for current bit)' 
               ]
      @angle = -90.0  # this tells gcodeutil what to do!

      #puts @cdia
      @cdia = (@cdia == 0.0) ? PhlatScript.bitDiameter * 2 : @cdia
      #puts @cdia
      defaults=[
         Sketchup.format_length(@cdia),
         Sketchup.format_length(@cdepth),
         Sketchup.format_length(@dia)
         ]
      # dropdown options can be added here
      list=["",
         "",
         ""                ]

      input = UI.inputbox(prompts, defaults, list, 'Counter Bore Options')
      # input is nil if user cancelled
      if (input)
         @cdia = Sketchup.parse_length(input[0])
         @cdepth = Sketchup.parse_length(input[1])
         @dia = Sketchup.parse_length(input[2])
         if (@dia < PhlatScript.bitDiameter)
            @dia = 0
         end
                     
         return (@cdia > PhlatScript.bitDiameter) && (@cdia > @dia) && (@cdepth < PhlatScript.materialThickness)
      else
         return false
      end
    end
    
   def activate
      super
      if getCounterBore
      else
         puts "getcounterbore cancelled"
         @dia = @cdia = 0
         #deselect the tool?
         Sketchup.active_model.select_tool(nil)
      end
   end

#counterbore version
   def onLButtonDown(flags, x, y, view)
      if ((flags & 32) == 32) || ((flags & 8) == 8) # ALT button or CTRL button, alt does not work in Ubuntu
         
         if ((flags & 4) == 4)  # want big hole too, SHIFT button down
            @dia = getDia()
         end
         #get params
         if getPattern()
            #place hole pattern, bottom left is clicked point
            np = @ip.position
            ccnt = 1
            for v in 0..(@vcount - 1)
               for h in 0..(@hcount - 1)
                  np.x = @ip.position.x + h * @hspace
                  np.y = @ip.position.y + v * @vspace
                  PlungeCut.cut(np, @depth, @dia, ccnt,@angle, @cdia, @cdepth)
                  ccnt += 1
               end
            end
         end
      else
#         if (@keyflag == 1)
         if ((flags & 4) == 4) # shift
            #prompt for diameter
            @dia = getDia()
            if (@dia > PhlatScript.bitDiameter)
               PlungeCut.cut(@ip.position, @depth, @dia,0, @angle, @cdia, @cdepth)
            else
               puts "Ignored dia <= bitdiameter"
            end
         else
            PlungeCut.cut(@ip.position, @depth, @dia, 0,@angle,@cdia, @cdepth)
         end
      end
      reset(view)
   end
   
   def statusText
      return "Select CounterBore plunge point, [SHIFT] for large hole, [ALT] for hole pattern"
   end

   end # class
   
  
end
# $Id$
