extends Node
# 作者:CK

# ============================================================
# Global Autoload — 全局状态 + 碳骨架分析 + IUPAC命名
# ============================================================

var atoms: Array = []
var bonds: Array = []
var next_id: int = 0
var unlocked_groups: Array = []

var show_h: bool = false
var stability_enabled: bool = true
var show_chiral: bool = true
var auto_clean_H: bool = true

# ============================================================
# 元素数据库
# ============================================================

var atom_colors = {
	"C":Color(0.25,0.25,0.25), "H":Color(0.95,0.95,0.95),
	"O":Color(1.0,0.2,0.2), "N":Color(0.2,0.3,1.0),
	"Cl":Color(0.2,0.8,0.2), "Br":Color(0.6,0.2,0.2),
	"F":Color(0.4,0.9,0.4), "S":Color(1.0,0.8,0.1),
	"P":Color(1.0,0.5,0.0), "K":Color(0.6,0.2,0.8),
	"Na":Color(0.3,0.3,1.0),
}

var atom_valence = {"C":4,"H":1,"O":2,"N":3,"Cl":1,"Br":1,"F":1,"S":2,"P":3,"K":1,"Na":1}
var atom_weight  = {"C":12,"H":1,"O":16,"N":14,"Cl":35,"Br":80,"F":19,"S":32,"P":31,"K":39,"Na":23}

# 中文碳数词头
const CN_NAMES = ["","甲","乙","丙","丁","戊","己","庚","辛","壬","癸"]
const SUB_NAMES = {1:"甲基",2:"乙基",3:"丙基",4:"丁基",5:"戊基"}
const SUB_DICT  = {"O":"羟基","N":"氨基","Cl":"氯","Br":"溴","F":"氟","S":"巯基","OH":"羟基","NH2":"氨基","COOH":"羧基","CHO":"醛基","NO2":"硝基"}

# ============================================================
# 化合物库 (IUPAC)
# ============================================================

var compound_lib = {
	# === 烷烃 ===
	"C1_H4_Bonds4":   {"name":"甲烷","info":"[b]Methane | CH₄[/b]\n天然气主要成分(占70-90%)，最简单的烷烃，无色无味可燃气体。沼气的主要成分，由有机物厌氧分解产生。温室效应潜能约为CO₂的28倍。天然气水合物(可燃冰)储量巨大，是未来潜在能源。工业上用于制氢、合成氨、甲醇和炭黑。"},
	"C2_H6_Bonds7":   {"name":"乙烷","info":"[b]Ethane | C₂H₆[/b]\n天然气中含量第二的组分(约5-10%)。石化工业关键原料，通过蒸汽裂解转化为乙烯——全球产量最大的有机化学品。临界温度32.2°C，常温下加压可液化。也是制备氯乙烷等乙基化试剂的前体。星际空间中已探测到乙烷的存在。"},
	"C3_H8_Bonds10":  {"name":"丙烷","info":"[b]Propane | C₃H₈[/b]\n液化石油气(LPG)主要成分(与丁烷混合)，常温加压即可液化，便于储运。燃烧热值高达50.3 MJ/kg，清洁燃料代表，广泛用于炊事、取暖、汽车动力(出租车常见)。R-290制冷剂代号，ODP=0、GWP极低，是环保型制冷剂。也是丙烯和乙烯裂解的副产物。"},
	"C4_H10_Bonds13": {"name":"丁烷","info":"[b]Butane | C₄H₁₀[/b]\n打火机气体、便携炉燃料。液化石油气成分之一，沸点仅-0.5°C故低温环境气化困难。存在正丁烷和异丁烷两种结构异构体——这是烷烃同分异构现象的起点(n=4时异构体数=2)。正丁烷可异构化为异丁烷以提高辛烷值，异丁烷也是烷基化汽油的关键原料。"},
	"C5_H12_Bonds16": {"name":"戊烷","info":"[b]Pentane | C₅H₁₂[/b]\n低沸点(36°C)非极性有机溶剂，实验室和工业常用。C₅H₁₂存在三种异构体：正戊烷(直链)、异戊烷(2-甲基丁烷)、新戊烷(2,2-二甲基丙烷)。新戊烷沸点仅9.5°C，是戊烷异构体中最低的，因其球形结构导致分子间作用力最弱。聚氨酯泡沫的发泡剂之一。"},
	"C6_H14_Bonds19": {"name":"己烷","info":"[b]Hexane | C₆H₁₄[/b]\n常用非极性溶剂，广泛用于食用油浸出提取(大豆油、菜籽油等)。正己烷具有神经毒性，长期暴露可致周围神经病变——制鞋、印刷行业需严格通风防护。沸点69°C，汽油组分之一。实验室常用石油醚即为戊烷/己烷混合物。异构体多达5种(n=6时烷烃异构体数)。"},
	"C5_H10_Bonds15": {"name":"环戊烷","info":"[b]Cyclopentane | C₅H₁₀[/b]\n五元环烷烃，存在于石油的环烷烃馏分中。环张力约26 kJ/mol(因键角偏离109.5°理想值)，但远低于环丙烷和环丁烷。作为聚氨酯硬泡的发泡剂替代CFC-11，ODP=0且GWP极低，是环保型物理发泡剂的代表。冰箱保温层中大量使用的环戊烷发泡体系。"},
	"C6_H12_Bonds18": {"name":"环己烷","info":"[b]Cyclohexane | C₆H₁₂[/b]\n六元环烷烃，几乎无环张力——椅式构象中所有C-C-C键角完美接近109.5°。常温下通过环翻转(ring flip)在椅式和扭船式间快速互变(~10⁵次/秒)。工业上通过苯催化加氢生产，主要用于制造己内酰胺(尼龙6单体)和己二酸(尼龙66单体)。非极性溶剂，溶解能力与己烷相当。"},
	# === 烯烃 ===
	"C2_H4_Bonds6":   {"name":"乙烯","info":"[b]Ethene | C₂H₄[/b]\n全球产量最大的有机化学品(年产量超2亿吨)，衡量国家石化工业水平的标志。最简单的烯烃，含C=C双键(键能611 kJ/mol，σ+π键)。植物内源激素——催熟水果(香蕉、番茄、猕猴桃)，\"一个烂苹果坏一筐\"的科学依据。聚合生成聚乙烯(PE)，是塑料工业的基石。"},
	"C3_H6_Bonds9":   {"name":"丙烯","info":"[b]Propene | C₃H₆[/b]\n全球产量第二的石化基础原料，蒸汽裂解和FCC工艺副产。聚丙烯(PP)单体——PP是全球用量第二大的合成树脂(仅次于PE)。也用于生产丙烯腈(腈纶)、环氧丙烷(聚氨酯)、异丙苯(苯酚/丙酮)和丁辛醇。甲基的存在使双键电子云不对称，比乙烯更易发生亲电加成。"},
	"C4_H8_Bonds12":  {"name":"1-丁烯","info":"[b]1-Butene | C₄H₈[/b]\n线性α-烯烃(LAO)的典型代表，双键在分子链末端。LLDPE(线性低密度聚乙烯)的重要共聚单体——通过插入丁基短支链调控聚乙烯的密度和结晶度。也用于生产聚1-丁烯(管道材料，抗蠕变优异)、仲丁醇、丁酮等。丁烯的四种异构体(1-丁烯、顺/反-2-丁烯、异丁烯)展示了烯烃位置异构和几何异构。"},
	"C6_H10_Bonds17": {"name":"环己烯","info":"[b]Cyclohexene | C₆H₁₀[/b]\n六元环烯烃，含一个环内双键。Diels-Alder反应中作为经典双烯体(diene)，与亲双烯体(如马来酸酐)发生[4+2]环加成——该反应是构建六元环最优雅的方法之一，Otto Diels和Kurt Alder因此获1950年诺贝尔化学奖。环己烯通过苯部分加氢或环己醇脱水制备。也是尼龙66生产中副产的回收物。"},
	# === 炔烃 ===
	"C2_H2_Bonds6":   {"name":"乙炔","info":"[b]Ethyne | C₂H₂[/b]\n最简单的炔烃，含C≡C三键(键能837 kJ/mol)。氧炔焰温度可达~3300°C，是少数能熔化钢铁的火焰之一，广泛用于金属焊接与切割。工业上由碳化钙(CaC₂)水解制得——俗称\"电石气\"。三键结构使其比乙烯(\"香蕉键\"模型)更易发生亲核加成。也是聚乙炔、氯乙烯(→PVC)、丙烯腈等化学品的前体。"},
	# === 醇/酚 ===
	"C2_H6_O1_Bonds8":{"name":"乙醇","info":"[b]Ethanol | C₂H₅OH[/b]\n酒类饮料的活性成分，人类使用历史超9000年。75%(v/v)水溶液是最常用的消毒剂——使蛋白质变性(非100%因需水分子参与变性过程)。工业上乙烯水合法或发酵法制备。体内经乙醇脱氢酶(ADH)代谢为乙醛(引起宿醉、肝损伤)，再经醛脱氢酶(ALDH)转化为乙酸。也是优良溶剂、燃料添加剂(乙醇汽油)。沸点78.4°C，与水、多数有机溶剂互溶。"},
	"C3_H8_O1_Bonds11":{"name":"丙-1-醇","info":"[b]Propan-1-ol | C₃H₇OH[/b]\n正丙醇，无色液体，气味似乙醇但更刺鼻。由丙烯经羰基合成(加CO/H₂)再还原制得。毒性约为乙醇的2-4倍——体内氧化为丙醛和丙酸，代谢比乙醇更慢。广泛用作溶剂、清洁剂、油墨和涂料稀释剂。也是正丙胺、乙酸丙酯等的前体。与水的共沸物含71.7%正丙醇(沸点87.7°C)。"},
	"C3_H8_O1_Bonds11b":{"name":"丙-2-醇","info":"[b]Propan-2-ol(异丙醇) | i-PrOH[/b]\n俗称\"擦拭酒精(rubbing alcohol)\"，医院和家庭常用消毒剂(70%水溶液)。比乙醇挥发更快、脱脂力更强，但不可饮用——体内氧化为丙酮(而非醛)，毒性较甲醇低但高于乙醇。丙烯水合法工业制备。电子工业中用于清洗电路板(无残留)，也是化妆品(爽肤水)中常见的溶剂组分。实验室用作DNA沉淀助剂(与乙醇配合)。"},
	"C3_H8_O3_Bonds13":{"name":"甘油","info":"[b]Glycerol | C₃H₈O₃[/b]\n丙三醇，最简单的三羟基醇。无色粘稠液体，强吸湿性，广泛用作化妆品保湿剂、食品甜味剂(E422)和药物赋形剂。动植物油脂(甘油三酯)水解或皂化的副产物——每生产1吨生物柴油约副产100kg甘油。硝化甘油(三硝酸甘油酯)剧烈炸药(Dynamite，诺贝尔1867年发明)，同时也是心绞痛急救药物(释放NO扩张冠脉)。"},
	"C6_H6_O1_Bonds16":{"name":"苯酚","info":"[b]Phenol | C₆H₅OH[/b]\n最简单的酚类化合物，OH直接连在苯环上。酚羟基使苯酚呈弱酸性(pKa≈10)，可溶于NaOH水溶液——区别于醇的经典鉴别方法。曾作为外科消毒剂(Lister首创无菌手术时代)，因皮肤腐蚀性已少用。工业上由异丙苯法制备(同时联产丙酮)。是环氧树脂(双酚A)、聚碳酸酯、阿司匹林、酚醛树脂(电木)等众多化工产品的关键原料。"},
	# === 醛/酮 ===
	"C1_H2_O1_Bonds4":{"name":"甲醛","info":"[b]Formaldehyde | HCHO[/b]\n最简单的醛，常温下为气体(沸点-19°C)，通常以37%水溶液(福尔马林)或固体多聚甲醛形式储存使用。强烈杀菌防腐——福尔马林用于标本固定、殡葬防腐。IARC第1类致癌物(鼻咽癌、白血病)，室内装修甲醛释放是重要健康隐患(来源：脲醛树脂胶粘剂的人造板材)。工业上甲醇氧化制得，是酚醛树脂、脲醛树脂、聚甲醛(POM工程塑料)和MDI(聚氨酯原料)的基础化学品。"},
	"C2_H4_O1_Bonds7":{"name":"乙醛","info":"[b]Ethanal | CH₃CHO[/b]\n无色刺激性气味液体(沸点20°C)。乙醇在体内的第一个代谢产物——乙醛是引起面部潮红、头痛、恶心等宿醉症状的元凶(特别是ALDH2酶活性低的东亚人群,约36%中国人携带突变)。也是乙酸、乙酸酐、季戊四醇、巴豆醛等化工产品的中间体。Wacker法(乙烯氧化法)是目前主流工业制备路线。三聚为三聚乙醛(催眠药)或四聚为四聚乙醛(杀螺剂)。"},
	"C3_H6_O1_Bonds10":{"name":"丙酮","info":"[b]Propanone | CH₃COCH₃[/b]\n最简单的酮，无色易挥发易燃液体(沸点56°C)，具有特征甜香味。优良的极性非质子溶剂——与水、乙醇、乙醚等互溶，广泛用于涂料稀释剂和实验室清洗。卸甲水(洗甲水)的主要成分，能快速溶解硝化纤维(指甲油成膜物)。人体在饥饿或糖尿病酮症时脂肪酸氧化产生酮体(丙酮、乙酰乙酸、β-羟丁酸)。工业上主要由异丙苯法联产(与苯酚协同生产)。"},
	# === 羧酸 ===
	"C1_H2_O2_Bonds5":{"name":"甲酸","info":"[b]Methanoic acid | HCOOH[/b]\n最简单的羧酸，蚁科昆虫(蚂蚁、蜜蜂)毒液中的活性成分——俗称\"蚁酸\"。无色有刺激性气味的发烟液体(pKa=3.75，酸性显著强于乙酸)。荨麻叶片上的刺毛也含甲酸，皮肤接触引起刺痛。工业上CO+NaOH→甲酸钠再酸化制得。用作皮革鞣制、纺织染色助剂、饲料防腐(酸化剂)。也是重要的化工中间体和还原剂(含醛基结构)。"},
	"C2_H4_O2_Bonds8":{"name":"乙酸","info":"[b]Ethanoic acid | CH₃COOH[/b]\n食醋的主要成分(含3-5%乙酸)，人类最早使用的酸之一。纯乙酸(冰醋酸)在16.6°C以下凝固为冰状晶体，故名。pKa=4.76，是羧酸的典型代表。工业制法包括甲醇羰基化(Monsanto法和Cativa法，是均相催化在工业上的标志性应用)和乙烯氧化法。用于生产醋酸乙烯酯(→PVAc白乳胶)、醋酸纤维素(→胶片基、烟嘴滤棒)、对苯二甲酸(→PET聚酯)等。"},
	"C3_H6_O2_Bonds11":{"name":"丙酸","info":"[b]Propanoic acid | C₂H₅COOH[/b]\n具有刺激性气味的无色液体，存在于汗液和某些奶酪中(瑞士奶酪的特征气味之一)。其钠盐和钙盐(丙酸钠E281、丙酸钙E282)是广泛使用的食品防腐剂——在面包、糕点中抑制霉菌生长(对酵母无效故可用于发酵面团)。也是合成除草剂(敌稗)、丙酸纤维素和某些香料酯的原料。埃曼塔尔奶酪中丙酸菌发酵产生丙酸和CO₂(形成孔洞)。"},
	"C4_H8_O2_Bonds14":{"name":"丁酸","info":"[b]Butanoic acid | C₃H₇COOH[/b]\n具有强烈腐臭黄油/呕吐物气味的短链脂肪酸，是体臭和口臭的贡献者之一。存在于腐败的牛奶、汗液和肠道发酵产物中。但其低碳酯(丁酸甲酯、丁酸乙酯等)却呈现愉悦的水果/花香，在食用香精中广泛使用。也是肠道上皮细胞的主要能量来源(丁酸由肠道菌群发酵膳食纤维产生)，具有抗炎和维持肠屏障功能的重要生理作用。"},
	"C7_H6_O2_Bonds19":{"name":"苯甲酸","info":"[b]Benzoic acid | C₆H₅COOH[/b]\n最简单的芳香族羧酸，白色片状结晶(熔点122°C)。苯环的存在使其pKa(4.2)略强于乙酸(4.76)——苯环的吸电子诱导效应。苯甲酸钠(E211)是应用最广的食品防腐剂之一(尤其在酸性饮料中，因抑菌作用依赖未解离的苯甲酸分子)。也是苯甲酸苄酯(杀疥螨药)、苯甲酸雌二醇(激素药)等药物的前体。工业上由甲苯液相空气氧化制备。"},
	"C2_H2_O4_Bonds10":{"name":"草酸","info":"[b]Oxalic acid | (COOH)₂[/b]\n最简单的二元羧酸，两个羧基直接相连。广泛存在于植物中——菠菜、大黄、甜菜叶含量尤其高(菠菜约0.5-1%鲜重)。在体内与钙离子形成不溶性草酸钙结晶，是肾结石(约80%肾结石含草酸钙)的主要成分。工业上用于除锈剂、漂白助剂、稀土元素提取。草酸盐在分析化学中用作标准还原剂(被KMnO₄氧化: 5C₂O₄²⁻+2MnO₄⁻+16H⁺→10CO₂+2Mn²⁺+8H₂O)。"},
	# === 酯 ===
	"C3_H6_O2_Bonds11e":{"name":"甲酸乙酯","info":"[b]Ethyl formate | HCOOC₂H₅[/b]\n甲酸与乙醇形成的酯，具有朗姆酒/浆果般特征香气。天然存在于朗姆酒、苹果、覆盆子和咖啡中。食品工业用作香料添加剂。也是高效低毒的熏蒸杀虫剂——用于仓储谷物和干果的害虫防治，其优势是快速降解为甲酸和乙醇(均为食品中天然存在物)，无持久性残留。"},
	"C4_H8_O2_Bonds14e":{"name":"乙酸乙酯","info":"[b]Ethyl acetate | CH₃COOC₂H₅[/b]\n乙酸与乙醇的酯化产物，最重要的工业酯类溶剂之一。具有愉悦的水果香气(梨、菠萝)，广泛用于指甲油去除剂(比丙酮更温和)、涂料稀释剂、油墨溶剂。属低毒性溶剂(允许在食品加工中用作萃取剂，如咖啡因脱除)。工业上由乙醇和乙酸在酸催化下酯化制备，也是葡萄酒等发酵饮料中的重要风味酯。"},
	# === 胺 ===
	"C1_H5_N1_Bonds6":{"name":"甲胺","info":"[b]Methylamine | CH₃NH₂[/b]\n最简单的胺，无色气体(沸点-6°C)，具有强烈的鱼腥/氨味——腐烂鱼类的特征气味正是三甲胺等低级胺所致。工业上由甲醇和氨催化反应制备。广泛用作药物合成原料(麻黄碱、卡马西平、咖啡因等均需甲胺作为甲基化试剂)。也用于生产农药(西维因等氨基甲酸酯类)、表面活性剂和照相显影剂。其盐酸盐为白色结晶，便于储存和运输。"},
	"C3_H9_N1_Bonds12":{"name":"丙-1-胺","info":"[b]Propan-1-amine | C₃H₇NH₂[/b]\n正丙胺，无色液体，具有氨样刺激性气味。比甲胺和乙胺碱性略强(脂肪胺的碱性随烷基给电子效应增强而增大)。用作药物合成中间体(如丙硫氧嘧啶、丙卡巴肼等)、农药原料(某些三嗪类除草剂)和缓蚀剂。与光气反应生成异氰酸丙酯，是合成某些聚氨酯的前体步骤。"},
	"N1_H3_Bonds3":   {"name":"氨","info":"[b]Ammonia | NH₃[/b]\n最简单的氮氢化合物，无色有强烈刺激性气味的气体。全球产量最大的无机化学品之一(年产量约2亿吨)——约80%用于化肥生产(尿素、硝酸铵等)。Haber-Bosch法合成氨(1909年)是人类历史上最重要的化学发明之一，使全球粮食产量实现质的飞跃(养活了约50%的世界人口)——Haber获1918年诺贝尔化学奖。液氨也是优良的制冷剂(R-717)。氮原子具孤对电子，使NH₃呈碱性和强配位能力(NH₃是经典配体)。"},
	# === 芳香烃 ===
	"C6_H6_Bonds15":  {"name":"苯","info":"[b]Benzene | C₆H₆[/b]\n最基础的单环芳香烃，6个C原子以sp²杂化形成平面正六边形环，6个p轨道侧面重叠形成离域大π键——芳香性的经典原型。C-C键长139pm(介于单键154pm和双键134pm之间)，验证了共振杂化理论。1825年Faraday首次从煤气中分离，1865年Kekulé提出环状结构。IARC第1类致癌物(白血病)，含苯汽油已被禁用。药物分子中最常见的骨架结构单元——含苯环的小分子药物占比超40%。"},
	"C7_H8_Bonds18":  {"name":"甲苯","info":"[b]Methylbenzene | C₆H₅CH₃[/b]\n苯环上一个H被甲基取代的芳香烃。常用有机溶剂——溶解能力与苯相当但毒性显著低于苯(甲苯不被代谢为致癌的环氧化物，而是氧化为苯甲酸经尿排出)。工业上从石油重整油或裂解汽油中提取。可被氧化为苯甲酸→苯酚(曾为主要工艺路线)，也是TNT炸药(三硝基甲苯)和聚氨酯原料(TDI)的直接前体。甲苯二异氰酸酯(TDI)是软质聚氨酯泡沫的关键单体。"},
	"C8_H10_Bonds21": {"name":"对二甲苯","info":"[b]p-Xylene | C₆H₄(CH₃)₂[/b]\n二甲苯的三种异构体(邻/间/对)之一，两个甲基在苯环对位。对二甲苯(PX)是聚酯产业链的核心原料——氧化为对苯二甲酸(PTA)后与乙二醇缩聚为PET(聚对苯二甲酸乙二醇酯，即涤纶纤维、饮料瓶、聚酯薄膜的原料)。PTA产能集中在中国(全球占比超60%)。对二甲苯从混合二甲苯中分离技术(吸附分离、深冷结晶)是石化工业的关键分离工艺之一。"},
	"C10_H8_Bonds27":{"name":"萘","info":"[b]Naphthalene | C₁₀H₈[/b]\n两个苯环稠合的最简多环芳烃(PAH)。白色片状结晶，具特征\"樟脑丸\"气味——曾广泛用于衣物防蛀(现已逐步被替代，因有一定毒性，IARC第2B类致癌物)。易升华(熔点80°C)，常温即有明显蒸气压。分子中含10个π电子(不符合4n+2的Hückel规则对多环的简单套用，但萘确实具芳香性)。工业上从煤焦油中提取，是邻苯二甲酸酐(→增塑剂)和萘系染料中间体的原料。"},
	# === 苯系衍生物 ===
	"C6_H5_Cl1_Bonds15":{"name":"氯苯","info":"[b]Chlorobenzene | C₆H₅Cl[/b]\n苯环上一个H被氯取代。无色液体，杏仁样气味。曾广泛用作工业溶剂和DDT生产原料，因氯代有机物的环境持久性现已限制使用。苯与氯气在Lewis酸(FeCl₃)催化下发生亲电取代制得——是芳环亲电卤化反应的典型教学案例。氯苯可用作制备苯酚(老法Dow法)、苯胺和多种农药中间体。氯原子使苯环钝化(吸电子诱导>给电子共轭)，进一步亲电取代主要发生在间位。"},
	"C6_H7_N1_Bonds17":{"name":"苯胺","info":"[b]Aniline | C₆H₅NH₂[/b]\n氨基直接连在苯环上的芳香胺。无色油状液体(暴露空气渐变为棕色——氧化产物有色)。1856年Perkin在合成奎宁的尝试中以苯胺为原料意外获得了苯胺紫(mauveine)——开启了合成染料工业的序幕。对乙酰氨基酚(扑热息痛/泰诺)的合成前体——苯胺→对硝基苯胺→对苯二胺→对乙酰氨基酚。工业上由硝基苯催化加氢(Béchamp还原法或气相催化加氢)制备。也是MDI(二苯基甲烷二异氰酸酯，聚氨酯硬泡原料)的关键前体。"},
	"C8_H8_O2_Bonds22":{"name":"水杨酸甲酯","info":"[b]Methyl salicylate | o-HOC₆H₄COOCH₃[/b]\n水杨酸邻位羟基与甲醇形成的酯。冬青油(gaultheria oil)的主要成分(含量>96%)，也具有类似桦木精油的特征香气。广泛用于外敷消炎镇痛制剂(Bengay、红花油等)、牙膏、口香糖和食品香精。水杨酸甲酯在体内快速水解为水杨酸，起抗炎作用。也是重要的合成中间体——在Perkin重排反应中加热异构化为水杨酸，再乙酰化即得阿司匹林。"},
	"C9_H8_O4_Bonds25":{"name":"阿司匹林","info":"[b]Aspirin | C₉H₈O₄[/b]\n乙酰水杨酸，经典非甾体抗炎药(NSAID)。1897年Felix Hoffmann在Bayer公司首次合成纯品(此前水杨酸虽有效但严重刺激胃)。作用机制：不可逆地乙酰化环氧化酶(COX-1)，抑制前列腺素合成→解热、镇痛、抗炎、抗血小板聚集。小剂量(75-100mg/d)长期服用用于预防心梗和脑梗(抗血小板)。WHO基本药物。每年全球消耗约4万吨。副作用：胃肠道损伤、Reye综合征(儿童病毒感染期禁用)。"},
	"C8_H9_NO2_Bonds22":{"name":"对乙酰氨基酚","info":"[b]Paracetamol | C₈H₉NO₂[/b]\n商品名泰诺(Tylenol)、扑热息痛。最常用的解热镇痛药之一——WHO基本药物目录核心药品。相比阿司匹林：胃肠道刺激更小(对COX-1抑制极弱)、儿童可用(无Reye综合征风险)。对乙酰氨基酚是苯胺衍生物——由对硝基苯酚经还原、乙酰化制得。主要风险为过量中毒——肝耗尽谷胱甘肽后，代谢产物NAPQI与肝蛋白共价结合导致急性肝坏死(是英美急性肝衰竭的首要原因)。N-乙酰半胱氨酸为特效解毒剂(补充GSH前体)。"},
	# === 含氮杂环 ===
	"C5_H5_N1_Bonds14":{"name":"吡啶","info":"[b]Pyridine | C₅H₅N[/b]\n六元芳香氮杂环。N的孤对电子在sp²轨道中(不参与π体系)使吡啶呈碱性(pKa约5.2)和亲核性——是有机合成中常用的碱催化剂和溶剂。具有特征恶臭(鱼腥味)。存在于煤焦油中，工业上由甲醛、乙醛和氨缩合制备。吡啶环是众多药物(异烟肼→抗结核、奥美拉唑→胃药、尼可刹米→呼吸兴奋剂)和农药(百草枯替代品敌草快、吡虫啉)的核心母核。尼古丁(烟草生物碱)含吡啶环。"},
	"C4_H4_N2_Bonds13":{"name":"嘧啶","info":"[b]Pyrimidine | C₄H₄N₂[/b]\n1,3-二氮杂六元芳香环。两个N原子均在sp²轨道中含孤对电子(不参与π体系)，吡啶环碱性因第二个N的吸电子效应而弱于吡啶。嘧啶是生命化学的核心——核酸的三个嘧啶碱基(胞嘧啶C、胸腺嘧啶T只存在于DNA、尿嘧啶U只存在于RNA)均以嘧啶为母核。众多抗病毒/抗癌药物靶向嘧啶代谢：5-氟尿嘧啶(5-FU)、阿糖胞苷、齐多夫定(AZT，首个抗HIV药物)。硫胺素(维生素B1)也含嘧啶环。"},
	"C4_H5_N1_Bonds11":{"name":"吡咯","info":"[b]Pyrrole | C₄H₅N[/b]\n五元芳香氮杂环。N的孤对电子参与π共轭(形成6π电子芳香体系)，因此吡咯几乎无碱性(pKa~-4)且亲电取代反应活性极高。四个吡咯环通过次甲基桥连构成卟啉(porphyrin)——卟啉环是生物界最重要的配体结构之一：血红素(Fe²⁺卟啉，血红蛋白/肌红蛋白的氧结合位点)、叶绿素(Mg²⁺卟啉，光合作用核心)、维生素B12(Co²⁺卟啉)。吡咯聚合生成导电聚合物聚吡咯(在传感器和超级电容器中有应用)。"},
	"C3_H4_N2_Bonds10":{"name":"咪唑","info":"[b]Imidazole | C₃H₄N₂[/b]\n1,3-二氮五元芳香环。一个N的孤对电子参与π体系(类似吡咯N)，另一个N的孤对电子在sp²轨道中呈碱性(pKa~7.0)——咪唑同时具有酸碱性两性特征。组氨酸(His)侧链即为咪唑基——其pKa约6.0使组氨酸成为生理pH下最有效的质子中继站(酶催化中广泛作为广义酸/碱催化剂)。咪唑环是多种抗真菌药(酮康唑、咪康唑、克霉唑)和质子泵抑制剂(西咪替丁)的药效团。也是离子液体中常见的阳离子骨架。"},
	"C8_H7_N1_Bonds23":{"name":"吲哚","info":"[b]Indole | C₈H₇N[/b]\n苯并吡咯——苯环与吡咯的[2,3-b]稠合。10π电子芳香体系。纯吲哚在低浓度时呈花香味(茉莉精油含~2.5%吲哚)，高浓度时呈粪便气味(大肠菌群分解色氨酸产生粪臭素即3-甲基吲哚)。色氨酸的侧链吲哚基是血清素(5-HT，\"快乐神经递质\")和褪黑素(睡眠激素)的核心结构。众多药物含吲哚环：舒马曲坦(抗偏头痛)、长春碱(抗癌)、利血平(降压/抗精神病)、麦角酸(LSD的前体)。吲哚化学是有机合成中最活跃的领域之一。"},
	"C9_H7_N1_Bonds25":{"name":"喹啉","info":"[b]Quinoline | C₉H₇N[/b]\n苯并吡啶——苯环与吡啶稠合。煤焦油中发现，Skraup合成法(苯胺+甘油+硫酸+氧化剂)是经典的杂环合成反应。喹啉环是抗疟药物的核心药效团——奎宁(quinine，金鸡纳树皮中的天然抗疟药，曾是最重要的抗疟手段，\"tonic water\"的苦味来源)、氯喹(chloroquine)、甲氟喹(mefloquine)。也是多种抗生素(环丙沙星等氟喹诺酮)和药物的骨架。8-羟基喹啉是重要的金属离子螯合剂和防腐剂。"},
	"C5_H4_N4_Bonds16":{"name":"嘌呤","info":"[b]Purine | C₅H₄N₄[/b]\n嘧啶与咪唑稠合的芳香杂环——自然界最重要的N-杂环结构。腺嘌呤(A)和鸟嘌呤(G)是DNA/RNA的编码碱基，承载所有生物的遗传信息。ATP(腺苷三磷酸)是细胞的\"能量货币\"(每天人体周转的ATP约等于体重！)。咖啡因(1,3,7-三甲基黄嘌呤，咖啡/茶中提神成分)、茶碱(茶中，抗哮喘)和可可碱(巧克力中)均为甲基化嘌呤衍生物——它们通过拮抗腺苷受体起兴奋作用。别嘌醇(痛风药)通过抑制黄嘌呤氧化酶减少尿酸生成。"},
	# === 含氧/硫杂环 ===
	"C4_H4_O1_Bonds10":{"name":"呋喃","info":"[b]Furan | C₄H₄O[/b]\n五元芳香含氧杂环。O原子的一个孤对电子参与π共轭(6π电子芳香体系)。无色易挥发液体，具类似氯仿的气味。毒性较高(致肝癌性)，需小心处理。呋喃环是利尿药呋塞米(furosemide，速尿)、抗溃疡药雷尼替丁(ranitidine，已因NDMA杂质问题退市)的重要母核。5-羟甲基糠醛(HMF)和糠醛(furfural)是重要的生物质平台化合物——由纤维素/半纤维素脱水制得，是可再生化工的关键中间体。"},
	"C4_H4_S1_Bonds10":{"name":"噻吩","info":"[b]Thiophene | C₄H₄S[/b]\n五元芳香含硫杂环。S原子的3p轨道参与π共轭，芳香性略弱于呋喃和吡咯(因S原子与C的原子轨道能级差异较大)。无色液体，气味与苯相似。煤焦油和石油中天然存在。噻吩环是多种药物的关键结构——头孢菌素类抗生素(头孢噻吩、头孢克洛等)均含噻吩环。也是导电聚合物聚噻吩(P3HT等)的单体——聚噻吩及其衍生物是有机太阳能电池、有机场效应晶体管(OFET)和OLED中的核心光电材料。"},
	# === 卤代烃 ===
	"C1_H3_Cl1_Bonds4":{"name":"氯甲烷","info":"[b]Chloromethane | CH₃Cl[/b]\n最简单的卤代烷。无色气体(沸点-24°C)，具有微甜气味。自然界中主要由海洋藻类和某些植物释放(全球年排放量约数百万吨)。曾广泛用作制冷剂(R-40)，因毒性和可燃性已被淘汰。化工上最重要的甲基化试剂之一——用于生产甲基纤维素、有机硅(通过Grignard试剂CH₃MgCl)和季铵盐表面活性剂。也是硅橡胶生产中不可缺少的封端剂(三甲基氯硅烷的前体)。"},
	"C2_H5_Cl1_Bonds8":{"name":"氯乙烷","info":"[b]Chloroethane | C₂H₅Cl[/b]\n无色气体(沸点12°C)或易挥发液体。历史上著名的局部麻醉喷雾——快速挥发使皮肤温度骤降至冰点产生麻醉效果(体育比赛中作为\"冷喷雾\"用于运动员急性伤痛处理，现已被更安全的替代品取代)。最重要的化工用途是作为乙基化试剂——生产四乙基铅(曾作为汽油抗爆剂，现已因铅污染全球禁用)和乙基纤维素等。也是制备格式试剂C₂H₅MgCl的原料。"},
}

# ============================================================
# 工具
# ============================================================

func get_color(sym:String)->Color: return atom_colors.get(sym,Color(0.6,0.2,0.8))
func get_valence(sym:String)->int: return atom_valence.get(sym,1)
func get_weight(sym:String)->int: return atom_weight.get(sym,39)
func get_next_id()->int: var id=next_id; next_id+=1; return id

func _find(id:int):
	for a in atoms:
		if is_instance_valid(a) and a.id==id: return a
	return null

# ---------- 指纹（仍用于库匹配） ----------
func generate_fingerprint()->String:
	var e={}; var bs=0
	for a in atoms:
		if is_instance_valid(a): e[a.symbol]=e.get(a.symbol,0)+1
	for b in bonds: bs+=b.get("bond_type",1)
	var p=[]; var o=["C","H","O","N"]
	for s in o:
		if e.get(s,0)>0: p.append(s+str(e[s]))
	for s in e:
		if s not in o and e[s]>0: p.append(s+str(e[s]))
	p.append("Bonds"+str(bs))
	return "_".join(p)

# ============================================================
# 结构分析 => 缩合式 + IUPAC名
# ============================================================

func analyze() -> Dictionary:
	print("[CK] analyze called, atoms=", atoms.size(), " bonds=", bonds.size())
	var result = {"formula":"","iupac":"","name":"","info":"","matched":false,"unsat":0}

	result.unsat = _calc_omega()
	result.formula = _condensed()

	var fp = generate_fingerprint()
	if compound_lib.has(fp):
		result.iupac  = compound_lib[fp].name
		result.name   = compound_lib[fp].name
		result.info   = compound_lib[fp].info
		result.matched = true
		return result

	result.iupac = _gen_alkane_name()
	result.name  = result.iupac
	return result


func _calc_omega()->int:
	var c=0; var h=0; var n=0; var x=0; var non_h=0
	for a in atoms:
		if not is_instance_valid(a): continue
		var s=a.symbol
		if s!="H": non_h+=1
		if s=="C": c+=1
		elif s=="H": h+=1
		elif s=="N": n+=1
		elif s in ["Cl","Br","F","I"]: x+=1
	if non_h<=1: return 0
	return (2*c + 2 + n - h - x) / 2


# ============================================================
# 缩合结构式
# ============================================================

const SUB = {"0":"₀","1":"₁","2":"₂","3":"₃","4":"₄","5":"₅","6":"₆","7":"₇","8":"₈","9":"₉"}

func _sub(n:int)->String:
	var s=str(n); var r=""
	for ch in s: r+=SUB.get(ch,ch)
	return r

func _h_on(a)->int:
	var h=0
	if not is_instance_valid(a): return 0
	for nb_id in a.neighbors:
		var nb=_find(nb_id)
		if nb and nb.symbol=="H": h+=1
	return h

func _bt(aid,bid)->int:
	for b in bonds:
		if (b.id1==aid and b.id2==bid) or (b.id1==bid and b.id2==aid):
			return b.get("bond_type",1)
	return 1

func _raw_formula()->String:
	var e={}
	for a in atoms:
		if is_instance_valid(a): e[a.symbol]=e.get(a.symbol,0)+1
	var p=[]
	for s in ["C","H","O","N","Cl","Br","F","S","P"]:
		if e.get(s,0)>0: p.append(s+_sub(e[s]))
	for s in e:
		if s not in ["C","H","O","N","Cl","Br","F","S","P"] and e[s]>0:
			p.append(s+_sub(e[s]))
	return "".join(p)

func _condensed()->String:
	var c_ids={}
	for a in atoms:
		if is_instance_valid(a) and a.symbol=="C": c_ids[a.id]=a
	if c_ids.is_empty(): return _raw_formula()

	# C-C 邻接 + 键型
	var adj={}; var btyp={}
	for id in c_ids: adj[id]=[]
	for b in bonds:
		if b.id1 in c_ids and b.id2 in c_ids:
			adj[b.id1].append(b.id2); adj[b.id2].append(b.id1)
			if not btyp.has(b.id1): btyp[b.id1]={}
			if not btyp.has(b.id2): btyp[b.id2]={}
			btyp[b.id1][b.id2]=b.get("bond_type",1)
			btyp[b.id2][b.id1]=b.get("bond_type",1)

	# 找最长碳链
	var best=[]
	for id in c_ids:
		if adj[id].size()<=1:
			var path=_dfs_chain(id,-1,adj,{})
			if path.size()>best.size(): best=path

	var is_ring = best.is_empty()
	if is_ring:
		# 环结构 → 走一圈构建公式
		var start_id=null
		for id in c_ids: start_id=id; break
		if start_id==null: return _raw_formula()
		var cycle=_walk_cycle(start_id,adj)
		var rparts=[]
		for i in range(cycle.size()):
			var cid=cycle[i]; var c=_find(cid); var h=_h_on(c); var next=cycle[(i+1)%cycle.size()]
			var bt=1
			if btyp.has(cid) and btyp[cid].has(next): bt=btyp[cid][next]
			var conn="=" if bt>=2 else "-"

			# 环上取代基
			var subs=[]
			for nb_id in c.neighbors:
				var nb=_find(nb_id)
				if nb==null: continue
				if nb.symbol=="C" and nb_id not in cycle:
					subs.append(_branch_str2(nb_id,cid,adj,btyp))
				elif nb.symbol!="C" and nb.symbol!="H":
					var bt2=_bt(cid,nb_id)
					var sc="=" if bt2>=2 else "-"
					sc+=nb.symbol; var nh2=_h_on(nb)
					if nh2>1: sc+=_sub(nh2)
					subs.append(sc)

			var core="C"
			if h==1: core="CH"
			elif h==2: core="CH"+_sub(2)
			if subs.is_empty():
				rparts.append(conn+core)
			else:
				rparts.append(conn+core+"("+",".join(subs)+")")
		return "["+"".join(rparts)+"]"

	# 沿链生成缩合式（带双键 = 符号）
	var parts=[]
	for i in range(best.size()):
		var cid=best[i]; var c=_find(cid); var h=_h_on(c)
		var brs=[]
		for nb_id in c.neighbors:
			var nb=_find(nb_id)
			if nb==null: continue
			if nb.symbol=="C" and nb_id not in best:
				var bt=_bt(cid,nb_id)
				var conn="=" if bt>=2 else "-"
				var sub_f=_branch_str2(nb_id,cid,adj,btyp)
				brs.append(sub_f)
			elif nb.symbol!="C" and nb.symbol!="H":
				# 杂原子取代基 O/N/S/Cl 等
				var bt=_bt(cid,nb_id)
				var conn="=" if bt>=2 else "-"
				var s=conn+nb.symbol
				var nh=_h_on(nb)
				if nh>1: s+=_sub(nh)
				brs.append(s)

		var core="C"
		if h==1: core="CH"
		elif h==2: core="CH"+_sub(2)
		elif h==3: core="CH"+_sub(3)
		elif h==4: core="CH"+_sub(4)

		var conn_str="-"
		if i>0:
			var bt=_bt(best[i-1],cid)
			if bt>=2: conn_str="="

		if i>0 and brs.is_empty():
			parts.append(conn_str+core)
		elif i>0:
			parts.append(conn_str+core+"("+",".join(brs)+")")
		elif brs.is_empty():
			parts.append(core)
		else:
			parts.append(core+"("+",".join(brs)+")")

	var result="".join(parts)
	if is_ring: result="["+result+"]"
	return result


func _branch_str2(start_id,parent_id,adj,btyp)->String:
	var c=_find(start_id); var h=_h_on(c)
	var sub_brs=[]
	for nb_id in c.neighbors:
		var nb=_find(nb_id)
		if nb==null: continue
		if nb.symbol=="C" and nb_id!=parent_id:
			var bt=_bt(start_id,nb_id)
			var conn="=" if bt>=2 else "-"
			sub_brs.append(conn+_branch_str2(nb_id,start_id,adj,btyp))
		elif nb.symbol!="C" and nb.symbol!="H":
			var bt=_bt(start_id,nb_id)
			var conn="=" if bt>=2 else "-"
			var s=conn+nb.symbol
			var nh=_h_on(nb)
			if nh>1: s+=_sub(nh)
			sub_brs.append(s)
	var core="C"
	if h==1: core="CH"
	elif h==2: core="CH"+_sub(2)
	elif h==3: core="CH"+_sub(3)
	if sub_brs.is_empty(): return core
	return core+"("+",".join(sub_brs)+")"

func _dfs_chain(current,parent,adj, visited)->Array:
	visited[current]=true
	var best=[current]
	for nb in adj[current]:
		if nb==parent: continue
		if visited.get(nb,false): continue
		var sub=_dfs_chain(nb,current,adj,visited)
		if sub.size()+1>best.size(): best=[current]+sub
	visited.erase(current)
	return best


func _walk_cycle(start,adj)->Array:
	var cycle=[start]
	var cur=start; var prev=-1
	for _iter in range(50):  # 安全上限
		var found=false
		for nb in adj[cur]:
			if nb!=prev:
				cycle.append(nb); prev=cur; cur=nb; found=true
				break
		if not found or cur==start:
			break
	if cycle.size()>1 and cycle[0]==cycle[cycle.size()-1]:
		cycle.pop_back()
	return cycle


# ============================================================
# IUPAC 命名
# ============================================================

func _gen_alkane_name()->String:
	# 只处理仅含 C/H 的分子
	for a in atoms:
		if is_instance_valid(a) and a.symbol not in ["C","H"]:
			return ""

	var c_ids={}
	for a in atoms:
		if is_instance_valid(a) and a.symbol=="C": c_ids[a.id]=a
	if c_ids.is_empty(): return ""

	var adj={}; var btyp={}
	for id in c_ids: adj[id]=[]
	for b in bonds:
		if b.id1 in c_ids and b.id2 in c_ids:
			adj[b.id1].append(b.id2); adj[b.id2].append(b.id1)
			if not btyp.has(b.id1): btyp[b.id1]={}
			if not btyp.has(b.id2): btyp[b.id2]={}
			btyp[b.id1][b.id2]=b.get("bond_type",1)
			btyp[b.id2][b.id1]=b.get("bond_type",1)

	# 所有端点间 DFS
	var all_chains=[]
	for id in c_ids:
		if adj[id].size()<=1:
			var path=_dfs_chain(id,-1,adj,{})
			all_chains.append(path)

	# 环结构：无端点 → 放弃自动命名，等数据库匹配
	if all_chains.is_empty():
		return ""

	var best=[]; var best_len=0
	for ch in all_chains:
		if ch.size()>best_len: best=ch; best_len=ch.size()

	var chain=best; var n=best_len
	if n>20: n=20

	# 找双键/三键位置
	var dbl_positions=[]
	var tri_positions=[]
	for i in range(n-1):
		var bt=1
		if btyp.has(chain[i]) and btyp[chain[i]].has(chain[i+1]):
			bt=btyp[chain[i]][chain[i+1]]
		if bt==2: dbl_positions.append(i+1)
		elif bt>=3: tri_positions.append(i+1)

	# 找取代基（双向编号）
	var subs_forward=_get_subs(chain,adj,n,false)
	var subs_backward=_get_subs(chain,adj,n,true)

	var sum_f=0; for k in subs_forward:
		for p in subs_forward[k]: sum_f+=int(p)
	var sum_b=0; for k in subs_backward:
		for p in subs_backward[k]: sum_b+=int(p)

	var subs=subs_forward; var dbl_pos=dbl_positions; var tri_pos=tri_positions
	if sum_b<sum_f:
		subs=subs_backward
		dbl_pos=[]; for p in dbl_positions: dbl_pos.append(n-p)
		tri_pos=[]; for p in tri_positions: tri_pos.append(n-p)

	dbl_pos.sort(); tri_pos.sort()

	# 构建取代基部分
	var parts=[]
	var pos_keys=subs.keys(); pos_keys.sort()
	for k in pos_keys:
		var pos_list=subs[k]; pos_list.sort()
		var ps=""
		for p in pos_list:
			if ps!="": ps+=","
			ps+=str(p)
		var prefix=""
		if pos_list.size()>1:
			var mults={2:"二",3:"三",4:"四"}
			prefix=mults.get(pos_list.size(),str(pos_list.size()))
		parts.append(ps+"-"+prefix+k)

	# 烯/炔键位置
	var ene=""; var yne=""
	if dbl_pos.size()>0:
		var dp=""; for pp in dbl_pos: if dp!="": dp+=","; dp+=str(pp)
		ene=dp+"-"
	if tri_pos.size()>0:
		var tp=""; for pp in tri_pos: if tp!="": tp+=","; tp+=str(pp)
		yne=tp+"-"

	var parent=CN_NAMES[min(n,10)]+"烷"
	if tri_pos.size()>0:
		parent=CN_NAMES[min(n,10)]+"炔"
	elif dbl_pos.size()>0:
		if dbl_pos.size()==1: parent=CN_NAMES[min(n,10)]+"烯"
		else: parent=CN_NAMES[min(n,10)]+"二烯"

	if parts.is_empty():
		return ene+yne+parent
	return "-".join(parts)+"-"+ene+yne+parent


func _get_subs(chain,adj,n,reverse)->Dictionary:
	# key: 取代基名(如"甲基"), val: 位置数组
	var result={}
	for i in range(n):
		var idx=i if not reverse else n-1-i
		var cid=chain[idx]
		for nb_id in adj[cid]:
			if nb_id in chain: continue
			var sub_name=_name_sub(nb_id,cid,adj)
			var pos=i+1
			if not result.has(sub_name): result[sub_name]=[]
			result[sub_name].append(pos)
	return result


func _name_sub(start_id,parent_id,adj)->String:
	# 递归命名取代基
	var chain=_dfs_sub_chain(start_id,parent_id,adj)
	var n=chain.size()
	if n<=5: return SUB_NAMES.get(n,"C"+str(n)+"H?")
	return str(n)+"碳基"

func _dfs_sub_chain(current,parent,adj)->Array:
	var best=[current]
	for nb in adj[current]:
		if nb==parent: continue
		var sub=_dfs_sub_chain(nb,current,adj)
		if sub.size()+1>best.size(): best=[current]+sub
	return best

# ============================================================
# 稳定性检测
# ============================================================
func check_unstable()->bool: return _check_peroxide() or _check_cumulene() or _check_azide()


func _check_peroxide()->bool:
	for bond in bonds:
		var a1=_find(bond.id1); var a2=_find(bond.id2)
		if a1 and a2 and a1.symbol=="O" and a2.symbol=="O":
			return true
	return false

func _check_cumulene()->bool:
	for a in atoms:
		if not is_instance_valid(a) or a.symbol!="C": continue
		var dbl=0
		for b in bonds:
			if b.get("bond_type",1)>=2 and (b.id1==a.id or b.id2==a.id):
				dbl+=1
		if dbl>=2: return true
	return false

func _check_azide()->bool:
	for bond in bonds:
		if bond.get("bond_type",1) >= 2:
			var a1=_find(bond.id1); var a2=_find(bond.id2)
			if a1 and a2 and a1.symbol=="N" and a2.symbol=="N":
				return true
	return false

func get_unstable_details()->Array:
	var msgs=[]
	if _check_peroxide(): msgs.append("peroxide")
	if _check_cumulene(): msgs.append("cumulene")
	if _check_azide(): msgs.append("azide")
	return msgs


# ============================================================
# 手性 R/S 计算 (CIP 简化版)
# ============================================================

func calc_rs(atom)->String:
	if atom.symbol!="C" or atom.neighbors.size()!=4: return ""
	var nbs=[]
	for nb_id in atom.neighbors:
		var nb=_find(nb_id)
		if nb: nbs.append({"a":nb,"p":_nb_pri(nb,atom.id)})
	if nbs.size()!=4: return ""
	nbs.sort_custom(func(x,y): return x.p < y.p)  # 低→高

	var v0=(nbs[1].a.position-atom.position).normalized()
	var v1=(nbs[2].a.position-atom.position).normalized()
	var v2=(nbs[3].a.position-atom.position).normalized()
	var vlo=(nbs[0].a.position-atom.position).normalized()

	var cross = (v1.x-v0.x)*(v2.y-v0.y) - (v1.y-v0.y)*(v2.x-v0.x)
	var toward = (v0.x*vlo.y - v0.y*vlo.x) > 0
	if toward: cross=-cross
	return "R" if cross>0 else "S"


func _nb_pri(nb,from_id)->float:
	var an=_anum(nb.symbol); var sub=0.0
	for nnb_id in nb.neighbors:
		if nnb_id==from_id: continue
		var nnb=_find(nnb_id)
		if nnb: sub+=_anum(nnb.symbol)
	return an+sub*0.01

func _anum(sym:String)->int:
	if sym=="H": return 1
	elif sym=="C": return 6
	elif sym=="N": return 7
	elif sym=="O": return 8
	elif sym=="F": return 9
	elif sym=="S": return 16
	elif sym=="Cl": return 17
	elif sym=="Br": return 35
	elif sym=="P": return 15
	elif sym=="I": return 53
	return 0


# ============================================================
# 手性全面检测：递归比较取代基整体结构
# ============================================================

func is_truly_chiral(atom)->bool:
	if atom.symbol != "C" or atom.neighbors.size() != 4: return false
	var sigs = []
	for nb_id in atom.neighbors:
		sigs.append(_substituent_sig(nb_id, atom.id))
	for i in range(4):
		for j in range(i+1, 4):
			if sigs[i] == sigs[j]:
				return false
	return true


func _substituent_sig(atom_id: int, from_id: int, depth: int = 0) -> String:
	if depth > 15: return "!"
	var atom = _find(atom_id)
	if not atom: return "?"
	var parts = []
	for nb_id in atom.neighbors:
		if nb_id == from_id: continue
		parts.append(_substituent_sig(nb_id, atom_id, depth + 1))
	parts.sort()
	var bt = 1
	for b in bonds:
		if (b.id1 == atom_id and b.id2 == from_id) or (b.id1 == from_id and b.id2 == atom_id):
			bt = b.get("bond_type", 1); break
	var sig = atom.symbol + str(bt)
	if parts.is_empty(): return sig
	return sig + "(" + ",".join(parts) + ")"
