###########################################################
# Manual Fielder Select v4.0
###########################################################
# Authors: PeacockSlayer, LittleCoaks



###########################################################
###########################################################

# Requires: 20678F8C 88061BD1
# Inject: 0x80678F8C
Start:
  mr r14, r3                  # move arg to allow backup without lost info (pointer)
  mflr r0                     # backup stack frame
  stw r0, 0x4(r1)
  stwu r1,-0x100(r1)
  stmw r3,0x8(r1)

# we store the previous manual select arg at 0x802EBF97; set r9 to the addr
GetOldSelect:
  lis r9, 0x802E
  ori r9, r9, 0xBF97

CheckUnfielded:
  lis r4, 0x8089
  ori r4, r4, 0x2701
  lbz r4, 0(r4)
  cmpwi r4, 0                 # make sure BallState is unfielded
  bne Deselect                # if the ball has been fielded already, set the previous manual select value to 0 (no selection) and end function; no manual selects after fielding ball

# store raw button inputs to r8
GetFielderInputs:
  lis r8, 0x8089
  ori r8, r8, 0x2898
  lhz r8, 0(r8)

# convert button input into manual select state and store in r4
# 0x0: Nothing
# 0x1: Pitcher
# 0x2: Catcher
# 0x3: Closest fielder
GetSelectState:
  lbz r4, 0(r9)               # get the previous state

CheckButton_Y:
  andi. r5, r8, 0x800
  cmpwi r5, 0x800
  bne CheckButton_X
  li r4, 0x1
  stb r4, 0(r9)               # store our current state to previous state addr

CheckButton_X:
  andi. r5, r8, 0x400
  cmpwi r5, 0x400
  bne CheckButton_R
  li r4, 0x2
  stb r4, 0(r9)               # store our current state to previous state addr

CheckButton_R:
  andi. r5, r8, 0x20
  cmpwi r5, 0x20
  bne CheckValidArgs
  li r4, 0x3
  stb r4, 0(r9)               # store our current state to previous state addr

CheckValidArgs:
  cmpwi r4, 0x4               # invalid manual select state; set previous state to 0 and return to avoid issues
  bge Deselect
  cmpwi r4, 0x0               # no manual select input selected; set previous state to 0 and return
  beq Deselect

ArgLogic:
  cmpwi r4, 3                 # for a manual select state of 3, we select closest fielder
  beq SelectClosest
  subi r4, r4, 1              # this is a clever way to save space; the pitcher and catcher states are just +1 of their fielder position
  b AssignFielder             # r4 is the fielder position to be selected; pitcher & catcher arg are already set

SelectClosest:
  li r5, 0x0                   # r5 = for loop increment
  li r4, 0x0                   # r4 = min distance fielder
  lis r6, 0x8088               # r6 = P position addr (ba = 0x8088F368)
  ori r6, r6, 0xF368
  lis r7, 0x8089               # r7 = Ball position addr (ba = 0x80890B38)
  ori r7, r7, 0xB38

# magic
ComputeClosest:
  lfs f28, 0(r7)
  lfs f29, 0(r6)
  fsub f30, f28, f29
  fadd f30, f30, f30
  fabs f30, f30
  lfs f28, 8(r7)
  lfs f29, 8(r6)
  fsub f28, f28, f29
  fadd f28, f28, f28
  fabs f28, f28
  fadd f30, f30, f28             # f30 = current min distance
  cmpwi r5, 0x0
  beq- StoreClosest
  fcmpo cr0, f10, f30
  blt- IncrementLoop_Closest

StoreClosest:
  fmr f10, f30                   # f10 = previous min distance
  mr r4, r5

IncrementLoop_Closest:
  addi r5, r5, 0x1
  addi r6, r6, 0x268
  cmpwi r5, 0x9
  bne+ ComputeClosest

  b AssignFielder

# Finally set desired player to 0xF
# r4 is the fielder id that we want to select
AssignFielder:
  lis r6, 0x8088
  ori r6, r6, 0xF53B            # base addr for fielder control status
  li r8, 0                      # for loop increment

Fielder_Loop:
  mulli r9, r8, 0x268
  lbzx r5, r9, r6
  cmpwi r5, 0xF                 # first we check if any fielders are selected (0xF) and set them to 0xC
  bne IncrementLoop_Fielder
  li r5, 0xC                    # a control status of 0xC tells the game to find the correct status of the fielder; very convienent for us
  stbx r5, r9, r6

IncrementLoop_Fielder:
  addi r8, r8, 1
  cmpwi r8, 0x9
  blt Fielder_Loop
  
  mulli r5, r4, 0x268           # compute offset for fielder addr
  li r7, 0xF                    # set to 0xF (selected)
  stbx r7, r5, r6
  lis r6, 0x8089                # Finally set the hand indicator
  ori r6, r6, 0x2800
  stb r4, 0x1(r6)
  stb r4, 0x7(r6)
  b EndFake

Deselect:
  li r4, 0x0
  stb r4, 0(r9)                 # set previous select arg to 0

# EndReal just means that we didn't do a manual select, so the game will proceed normally
# we properly replace the instruction that we overwrote after restoring the stack
EndReal:
  lmw r3,0x8(r1)                # restore stack
  lwz r0, 0x104(r1)
  addi r1,r1,0x100
  mtlr r0
  mr r3, r14
  lbz r0, 0x1bd1(r6)            # Perform op where we inject
  b End

# EndFake means we will trick the game not to continue trying to assign control status after a manual select
# by setting r0 to 1 after restoring the stack, the game won't assign another fielder; nice!
EndFake:
  lmw r3,0x8(r1)                # restore stack
  lwz r0, 0x104(r1)
  addi r1,r1,0x100
  mtlr r0
  mr r3, r14
  li r0, 1

End:




