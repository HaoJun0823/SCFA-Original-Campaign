#*****************************************************************************
#* File: schook/lua/ai/AIBehaviors.lua
#* Summary: SC campaign compatibility hook - provide CDROverchargeBehavior
#*          that FA's AIBehaviors.lua lacks, forwarding to OpBehaviors.lua
#*****************************************************************************

# SC campaign scripts (SCCA_E04, SCCA_R05) call:
#   import('/lua/ai/AIBehaviors.lua').CDROverchargeBehavior(cdrPlatoon)
# FA's AIBehaviors.lua does not have this function, but FA's
# ai/opai/OpBehaviors.lua has an enhanced version with CDRData support
# (LeashPosition, LeashRadius, RunAway). Forward to that implementation.

CDROverchargeBehavior = import('/lua/ai/opai/OpBehaviors.lua').CDROverchargeBehavior
