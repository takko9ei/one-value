# Zero-Sum Allocation Shooter (零和分配射击游戏 / ゼロ和分配シューティング)

[English](#english) | [日本語](#日本語) | [中文](#中文)

---

## <a id="english"></a>English

This project is a top-down shooter game based on a "zero-sum resource allocation" mechanism, where the core gameplay revolves around resource management and trade-offs.

### Game Design Philosophy

The design philosophy of this project is: "**All resources share a single pool.**"
The player has a fixed maximum total amount of points (e.g., 100 points) throughout the entire game. The gameplay requires the player to observe the characteristics of the upcoming enemies and weigh the distribution of these limited points. Players must balance allocating points to player buffs (such as attack power, max health, multiple projectiles) and enemy debuffs (such as slow down, attack/defense reduction) to find the optimal solution to clear the level.

### Typical Gameplay Loop

1. **Game Starts**.
2. **First Level Allocation**: Allocate points by dragging the sliders in the allocation interface.
3. **Enter First Level**: Defeat the set target number of enemies to automatically complete the level.
4. **Second Level Allocation**: Enter a new round of trade-offs, shuffle and reallocate points.
5. **And so on**, until all levels are cleared.

> **Retry and Failure Penalty**: If you fail a challenge in any level, you can simply press the **Retry** button on the UI or press the **R** key on your keyboard. The game will immediately restart from the resource allocation phase of the current level.
> **Game Length**: The project currently contains 5 levels.

### Numerical Design Intent and Level Guide

The overall game difficulty might be slightly high, but all levels have been tested and verified to be clearable. Players are encouraged to boldly use extreme point allocations:

- **Level 1 (Swarm)**: Features a massive number of fast-moving enemies with decent damage. Players should prioritize **projectile count** (increasing bullets fired per shot) to ensure AoE clearing capabilities.
- **Level 2 (Golem)**: Features enemies with extremely high health and defense, but extremely slow movement speed. Players should allocate **very high attack power** to forcefully pierce through their armor.
- **Level 3 (Hound)**: Features extremely fast enemies with high attack power. Players should heavily invest in the **enemy slow debuff** to reduce enemy movement speed, moderately increase their own attack power, and increase the **player's dash count (stamina)** to kite enemies.
- **Level 4 (Leech)**: Features an extremely massive number of very fast enemies with low attack power. Players should allocate **extremely high health** and moderately increase **projectile count** to tank the damage inside the enemy swarm until the level is cleared.
- **Level 5 (Warden)**: Features enemies with balanced stats. Players should moderately **reduce enemy speed**, moderately **increase attack power**, and moderately **reduce enemy defense**.

### Developer Guide: How to Add New Levels and Enemies

#### If using AI

Let AI read ARCHITECTURE.md to understand the architecture, and then modify the code.

#### How to Add New Enemies

1. **Create New Enemy Scene**: Create a new scene inheriting from `prefab/EnemyBase.tscn` (or the base enemy prefab).
2. **Modify Initial Stats**: Select the root node of the new enemy, and directly set its initial stats (like base health, movement speed, attack, defense, etc.) in the **Inspector** panel on the right.
3. **Change Visual Appearance**: Modify its internal `Sprite2D` node to replace the texture asset.

#### How to Add New Levels and Scene Flow

1. **Create New Level Scene**: Create a new scene inheriting from `scene/LevelBase.tscn`.
2. **Configure Wave Spawner**:
   - Select the `LevelController` child node/scene in the scene tree.
   - In the **Inspector** panel on the right, drag your newly created enemy scene into the `Enemy Scene` property slot.
   - Adjust other parameters below: modify `Total Enemies To Kill`, `Spawn Interval`, and `Max Enemies On Screen`.
3. **Configure GameManager for New Transitions**:
   - Open the global controller script `script/GameManager.gd`.
   - Find the `@export var level_scenes: Array[String]` variable at the top.
   - Add the path of your newly configured level scene (e.g., `"res://scene/level6.tscn"`) to the end of this array.
   - **Architecture Overview**: Regarding how to modify the Controller code to implement scene transitions — **you don't need to modify it at all**. The `LevelController` internally encapsulates the logic for listening to the `died` signal of each spawned monster and counting kills. Once the kill count reaches the value you set in the Inspector, it automatically stops spawning monsters and calls `GameManager.next_level()`. The `GameManager` then increments the current level index and seamlessly loads the next path from the `level_scenes` array. You only need to drop the scene into the array in the editor; the entire architecture features a highly decoupled design.

---

## <a id="日本語"></a>日本語

本作は、「ゼロサムリソース分配」メカニズムに基づいたトップダウンシューティングゲームです。リソースの駆け引きがゲームプレイの核心となります。

### ゲームデザインの考え方

このプロジェクトのデザインコンセプトは、「**すべてのリソースが1つの値を共有する**」ことです。
プレイヤーはゲーム全体を通して固定の上限となる総ポイント（例：100ポイント）を持ちます。今後の敵の特性を観察し、限られた総ポイントの中で、プレイヤーのバフ（攻撃力、最大HP、複数弾など）と敵のデバフ（移動速度低下、攻撃力/防御力低下など）の割り当てを比較考量し、クリアのための最適解を見つけ出すことが求められます。

### 典型的なゲームフロー

1. **ゲーム開始**。
2. **第1ステージのポイント分配**：割り当てUIでスライダーをドラッグしてポイントを振ります。
3. **第1ステージ開始**：設定された目標数の敵を倒すと、自動的にステージクリアとなります。
4. **第2ステージのポイント分配**：新たな駆け引きに入り、ポイントをリセットして再分配します。
5. **これを繰り返し**、全ステージをクリアします。

> **リトライと失敗のペナルティ**：いずれかのステージで挑戦に失敗した場合、UI上の **Retry** ボタンを押すか、キーボードの **R** キーを押すことで、現在のステージのポイント分配フェーズから即座にやり直すことができます。
> **ゲームの長さ**：現在、プロジェクトには合計5つのステージが含まれています。

### 数値設定の意図とステージ攻略

ゲーム全体の難易度は少し高めかもしれませんが、すべてのステージはクリア可能であることがテストされています。プレイヤーには極端なステータス振りを大胆に行うことが求められます：

- **第1ステージ (Swarm)**：大量で移動速度が速く、ダメージも低くない敵が出現します。プレイヤーは範囲攻撃での殲滅力を確保するため、**弾数**（1回の射撃で発射される弾の数）を優先して上げる必要があります。
- **第2ステージ (Golem)**：HPと防御力が極めて高く、移動速度が極端に遅い敵が出現します。装甲を強引に貫通するために、**非常に高い攻撃力**を振る必要があります。
- **第3ステージ (Hound)**：移動速度が非常に速く、攻撃力の高い敵が出現します。プレイヤーは**敵の速度デバフ**に多くポイントを振って敵の移動速度を下げ、自身の攻撃力を適度に上げつつ、敵を引き撃ちするために**プレイヤーのダッシュ回数（スタミナ）**を増やす必要があります。
- **第4ステージ (Leech)**：攻撃力が低く、数が非常に多く、移動速度が極めて速い敵が出現します。プレイヤーは**極めて高いHP**を振り、**弾数**を適度に増やして、クリアするまで敵の群れの中でダメージを耐え凌ぐ必要があります。
- **第5ステージ (Warden)**：敵のステータスが比較的バランスが取れています。適度に**敵の速度を下げ**、適度に**攻撃力を上げ**、適度に**敵の防御力を下げる**必要があります。

### 開発者向けガイド：新しいステージと敵の追加方法

#### AIを使う場合

ARCHITECTURE.mdを読ませてから、ARCHITECTURE.mdを参考にしてコードを修正するように指示する。

#### 新しい敵の追加方法

1. **新しい敵シーンの作成**：`prefab/EnemyBase.tscn`（または基本の敵プレハブ）を継承した新しいシーンを作成します。
2. **初期ステータスの変更**：新しい敵のルートノードを選択し、右側の **Inspector（インスペクター）** パネルで、その敵の初期ステータス（基礎HP、移動速度、攻撃力、防御力など）を直接設定できます。
3. **外観の変更**：内部の `Sprite2D` ノードを変更して、対応するテクスチャ素材を置き換えます。

#### 新しいステージとシーン遷移の追加方法

1. **新しいステージシーンの作成**：`scene/LevelBase.tscn` を継承した新しいシーンを作成します。
2. **ウェーブスポーナーの設定**：
   - シーンツリーで `LevelController` 子ノード/シーンを選択します。
   - 右側の **Inspector** パネルで、作成した新しい敵シーンを `Enemy Scene` プロパティスロットにドラッグします。
   - 続けて他のパラメータを調整します：`Total Enemies To Kill`（このステージで倒すべき敵の総数）、`Spawn Interval`（敵がスポーンする間隔）、および `Max Enemies On Screen`（画面上の敵の最大数制限）を変更します。
3. **新しい遷移を実装するための GameManager の設定**：
   - プロジェクトのグローバル制御スクリプト `script/GameManager.gd` を開きます。
   - 上部にある `@export var level_scenes: Array[String]` 変数を見つけます。
   - 設定したばかりの新しいステージシーンのパス（例：`"res://scene/level6.tscn"`）をこの配列の末尾に追加します。
   - **原理の概要**：遷移を実装するために Controller のコードをどのように変更するかについてですが、実は**変更する必要は全くありません**。`LevelController` 内部には、生成された各モンスターの `died` シグナルのリッスンとカウントロジックがすでにカプセル化されています。キル数が Inspector で設定した値に達すると、自動的にモンスターのスポーンを停止し、`GameManager.next_level()` を呼び出します。すると `GameManager` は現在のステージインデックスに 1 を足し、`level_scenes` 配列から次のパスを読み込んでシームレスに切り替えます。エディタ上でシーンを配列に放り込むだけで済み、アーキテクチャ全体が高度に疎結合な設計を採用しています。

---

## <a id="中文"></a>中文

本项目是一款基于“零和资源分配”机制的俯视角射击类游戏，玩法核心通过资源博弈机制展开。

### 游戏设计思路

这个项目的设计思路是：“**所有资源共用一个值**”。
玩家在游戏全局拥有固定上限的总点数（例如 100 点）。游戏的玩法是通过观察即将面临的敌人的特点，在有限的总点数内，权衡并分配玩家的增益属性（如攻击力、最大血量、多重弹丸）和怪物的减益属性（如减速 Debuff、削弱攻击/防御），从而寻找最优解以实现通关。

### 典型游戏流程

1. **游戏开始**。
2. **分配第一关资源**：在加点界面拉动滑块进行加点。
3. **进入第一关**：击杀本关设定的目标敌人数量后，自动完成本关。
4. **分配第二关资源**：进入新一轮博弈，重新洗牌并分配点数。
5. **以此类推**，直到通关全部关卡。

> **重置与失败惩罚**：在任意关卡如果挑战失败，可以直接按界面上的 **Retry** 按钮或按下键盘 **R** 键，游戏会立刻从当前关卡的资源分配阶段重开。
> **游戏长度**：目前项目一共包含 5 个关卡。

### 数值设计的企图与关卡攻略

游戏整体难度可能略高，但是所有关卡均已经测试过可以通过。需要玩家大胆使用极限加点：

- **第一关 (Swarm)**：这一关有数量庞大、移动速度快、伤害不低的敌人。要求玩家优先点出**弹丸数量**（增加每次射出的子弹数）以保证群攻清杂。
- **第二关 (Golem)**：这一关有血量极厚、防御极高，但是移动速度极其缓慢的敌人。要求玩家点出**非常高的攻击力**来强行穿透护甲。
- **第三关 (Hound)**：这一关有移动速度极快、攻击力很高的敌人。要求玩家点高**怪物速度 Debuff** 降低怪物移速，并适当增加自身攻击力，以及增加**玩家的冲刺次数（耐力）**来拉扯敌人。
- **第四关 (Leech)**：这一关有低攻击、数量极度庞大、移动速度极快的敌人。要求玩家点出**极高的血量**以及适当增加**弹丸数量**，在怪堆里面硬抗伤害直到通关。
- **第五关 (Warden)**：这一关的怪物各项属性比较均衡。要求适当地**降低敌人速度**、适当地**加高攻击**，以及适当地**削弱敌人的防御**。

### 开发者指南：如何添加新关卡与新敌人

#### 如何添加新敌人

1. **创建新敌人场景**：新建一个场景并继承自 `prefab/EnemyBase.tscn`（或基础的敌人预制体）。
2. **修改初始数值**：选中新敌人的根节点，在右侧的 **Inspector（属性检查器）** 面板中，可以直接设置该敌人的初始数值（如基础血量、移动速度、攻击力、防御力等）。
3. **更换外观表现**：修改其内部的 `Sprite2D` 节点以更换相应的贴图素材。

#### 如何添加新关卡与场景流转

1. **创建新关卡场景**：新建一个场景并继承自 `scene/LevelBase.tscn`。
2. **配置波次生成器**：
   - 在场景树中选中 `LevelController` 这一子节点/场景。
   - 在右侧的 **Inspector** 面板中，将你制作好的新敌人场景拖入 `Enemy Scene` 属性插槽中。
   - 在下方继续调整其它参数：修改 `Total Enemies To Kill`（这一关需要打败的敌人总数）、`Spawn Interval`（生成敌人的间隙时间）、以及 `Max Enemies On Screen`（同屏最大敌人数量限制）。
3. **配置 GameManager 实现新跳转**：
   - 打开项目全局控制脚本 `script/GameManager.gd`。
   - 找到顶部的 `@export var level_scenes: Array[String]` 变量。
   - 将你刚配置好的新关卡场景路径（例如 `"res://scene/level6.tscn"`）添加到这个数组的末尾。
   - **原理概述**：关于如何修改 Controller 代码实现跳转——其实**完全不需要修改**。由于 `LevelController` 内部已经封装好针对每个生成怪物 `died` 信号的监听及统计逻辑。一旦击杀达到你在 Inspector 设置的设定值，它就会自动停止刷怪并调用 `GameManager.next_level()`。而 `GameManager` 会将当前关卡索引加一，并读取 `level_scenes` 数组中的下一个路径执行无缝切换。你只需在编辑器里把场景扔进数组即可，整个架构采用了高度解耦的设计。
