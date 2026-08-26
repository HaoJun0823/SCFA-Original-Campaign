version = 3
ScenarioInfo = {
    name = 'SCCA_A04',
    description = 'Campaign Map: Not Intended for Multiplayer Play',
    type = 'campaign',
    starts = true,
    preview = '',
    size = {1024, 1024},
    map = '/maps/SCCA_R04/SCCA_R04.scmap',
    save = '/maps/SCCA_A04/SCCA_A04_save.lua',
    script = '/maps/SCCA_A04/SCCA_A04_script.lua',
    Configurations = {
        ['standard'] = {
            teams = {
                { name = 'FFA', armies = {'Player','Cybran','Civilian','Nodes','Nexus_Defense',} },
            },
            customprops = {
            },
        },
    }}
