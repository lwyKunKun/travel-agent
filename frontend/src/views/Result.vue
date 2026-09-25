<template>
  <div class="result-container">
    <!-- 页面头部 -->
    <div class="page-header">
      <a-button class="back-button" size="large" @click="goBack"> ← 返回首页 </a-button>
      <a-space size="middle">
        <a-button v-if="!editMode" @click="toggleEditMode" type="default">
          ✏️ 编辑行程
        </a-button>
        <a-button v-else @click="saveChanges" type="primary"> 💾 保存修改 </a-button>
        <a-button v-if="editMode" @click="cancelEdit" type="default">
          ❌ 取消编辑
        </a-button>

        <!-- 导出按钮 -->
        <a-dropdown v-if="!editMode">
          <template #overlay>
            <a-menu>
              <a-menu-item key="image" @click="exportAsImage">
                📷 导出为图片
              </a-menu-item>
              <a-menu-item key="pdf" @click="exportAsPDF"> 📄 导出为PDF </a-menu-item>
            </a-menu>
          </template>
          <a-button type="default"> 📥 导出行程 <DownOutlined /> </a-button>
        </a-dropdown>
      </a-space>
    </div>

    <!-- 降级数据警告横幅: LLM生成失败时后端会打上 is_fallback 标记 -->
    <a-alert
      v-if="tripPlan && tripPlan.is_fallback"
      class="fallback-alert"
      type="warning"
      show-icon
      banner
      message="⚠️ 当前行程为降级兜底数据（LLM 未参与生成）"
      :description="
        tripPlan.fallback_reason ||
        '行程由高德真实POI数据自动编排，缺少AI个性化建议。请检查后端 LLM_API_KEY 配置后重新生成。'
      "
    />

    <div v-if="tripPlan" class="content-wrapper">
      <!-- 侧边导航 -->
      <div class="side-nav">
        <a-affix :offset-top="80">
          <a-menu mode="inline" :selected-keys="[activeSection]" @click="scrollToSection">
            <a-menu-item key="overview">
              <span>📋 行程概览</span>
            </a-menu-item>
            <a-menu-item key="budget" v-if="tripPlan.budget">
              <span>💰 预算明细</span>
            </a-menu-item>
            <a-menu-item key="map">
              <span>📍 景点地图</span>
            </a-menu-item>
            <a-sub-menu key="days" title="📅 每日行程">
              <a-menu-item v-for="(day, index) in tripPlan.days" :key="`day-${index}`">
                第{{ day.day_index + 1 }}天
              </a-menu-item>
            </a-sub-menu>
            <a-menu-item key="weather">
              <span>🌤️ 天气信息</span>
            </a-menu-item>
          </a-menu>
        </a-affix>
      </div>

      <!-- 主内容区 -->
      <div class="main-content">
        <!-- 顶部信息区:左侧概览+预算,右侧地图 -->
        <div class="top-info-section">
          <!-- 左侧:行程概览和预算明细 -->
          <div class="left-info">
            <!-- 行程概览 -->
            <a-card
              id="overview"
              :title="`${tripPlan.city}旅行计划`"
              :bordered="false"
              class="overview-card"
            >
              <template #extra>
                <span class="overview-days">{{ tripPlan.days.length }} 天行程</span>
              </template>
              <div class="overview-content">
                <div class="info-item">
                  <span class="info-label">📅 日期</span>
                  <span class="info-value"
                    >{{ tripPlan.start_date }} 至 {{ tripPlan.end_date }}</span
                  >
                </div>
                <!-- 行程统计 -->
                <div class="overview-stats">
                  <div class="stat-box">
                    <div class="stat-num">{{ tripPlan.days.length }}</div>
                    <div class="stat-label">天行程</div>
                  </div>
                  <div class="stat-box">
                    <div class="stat-num">{{ totalAttractions }}</div>
                    <div class="stat-label">个景点</div>
                  </div>
                  <div class="stat-box">
                    <div class="stat-num">
                      ¥{{ formatMoney(tripPlan.budget?.total || 0) }}
                    </div>
                    <div class="stat-label">预估总预算</div>
                  </div>
                </div>
                <div class="info-item">
                  <span class="info-label">💡 旅行建议</span>
                  <span class="info-value">{{ tripPlan.overall_suggestions }}</span>
                </div>
              </div>
            </a-card>

            <!-- 预算明细 -->
            <a-card
              id="budget"
              v-if="tripPlan.budget"
              title="💰 预算明细"
              :bordered="false"
              class="budget-card"
            >
              <div class="budget-grid">
                <div class="budget-item">
                  <div class="budget-label">景点门票</div>
                  <div class="budget-value">
                    ¥{{ formatMoney(tripPlan.budget.total_attractions) }}
                  </div>
                </div>
                <div class="budget-item">
                  <div class="budget-label">酒店住宿</div>
                  <div class="budget-value">
                    ¥{{ formatMoney(tripPlan.budget.total_hotels) }}
                  </div>
                </div>
                <div class="budget-item">
                  <div class="budget-label">餐饮费用</div>
                  <div class="budget-value">
                    ¥{{ formatMoney(tripPlan.budget.total_meals) }}
                  </div>
                </div>
                <div class="budget-item">
                  <div class="budget-label">交通费用</div>
                  <div class="budget-value">
                    ¥{{ formatMoney(tripPlan.budget.total_transportation) }}
                  </div>
                </div>
              </div>
              <div class="budget-total">
                <span class="total-label">预估总费用</span>
                <span class="total-value">¥{{ formatMoney(tripPlan.budget.total) }}</span>
              </div>
            </a-card>
          </div>

          <!-- 右侧:地图 -->
          <div class="right-map">
            <a-card id="map" title="📍 景点地图" :bordered="false" class="map-card">
              <div id="amap-container" style="width: 100%; height: 100%"></div>
            </a-card>
          </div>
        </div>

        <!-- 每日行程:可折叠 -->
        <a-card title="📅 每日行程" :bordered="false" class="days-card">
          <a-collapse v-model:activeKey="activeDays" accordion>
            <a-collapse-panel
              v-for="(day, index) in tripPlan.days"
              :key="index"
              :id="`day-${index}`"
            >
              <template #header>
                <div class="day-header">
                  <span class="day-title">第{{ day.day_index + 1 }}天</span>
                  <span class="day-date">{{ day.date }}</span>
                </div>
              </template>

              <!-- 行程基本信息 -->
              <div class="day-info">
                <div class="info-row">
                  <span class="label">📝 行程描述:</span>
                  <span class="value">{{ day.description }}</span>
                </div>
                <div class="info-row">
                  <span class="label">🚗 交通方式:</span>
                  <span class="value">{{ day.transportation }}</span>
                </div>
                <div class="info-row">
                  <span class="label">🏨 住宿:</span>
                  <span class="value">{{ day.accommodation }}</span>
                </div>
              </div>

              <!-- 景点安排 -->
              <a-divider orientation="left">🎯 景点安排</a-divider>
              <a-list :data-source="day.attractions" :grid="{ gutter: 16, column: 2 }">
                <template #renderItem="{ item, index }">
                  <a-list-item>
                    <a-card size="small" class="attraction-card">
                      <!-- 卡片标题: 景点名 + 信息来源标签 -->
                      <template #title>
                        <span class="attraction-title">
                          {{ item.name }}
                          <a-tag
                            v-for="src in item.sources || []"
                            :key="src"
                            :color="sourceTagColor(src)"
                            class="source-tag"
                          >
                            {{ src }}
                          </a-tag>
                        </span>
                      </template>
                      <!-- 编辑模式下的操作按钮 -->
                      <template #extra v-if="editMode">
                        <a-space>
                          <a-button
                            size="small"
                            @click="moveAttraction(day.day_index, index, 'up')"
                            :disabled="index === 0"
                          >
                            ↑
                          </a-button>
                          <a-button
                            size="small"
                            @click="moveAttraction(day.day_index, index, 'down')"
                            :disabled="index === day.attractions.length - 1"
                          >
                            ↓
                          </a-button>
                          <a-button
                            size="small"
                            danger
                            @click="deleteAttraction(day.day_index, index)"
                          >
                            🗑️
                          </a-button>
                        </a-space>
                      </template>

                      <!-- 景点图片 -->
                      <div class="attraction-image-wrapper">
                        <img
                          :src="getAttractionImage(item.name, index)"
                          :alt="item.name"
                          class="attraction-image"
                          @error="handleImageError"
                        />
                        <div class="attraction-badge">
                          <span class="badge-number">{{ index + 1 }}</span>
                        </div>
                        <div v-if="item.ticket_price" class="price-tag">
                          ¥{{ item.ticket_price }}
                        </div>
                      </div>

                      <!-- 编辑模式下可编辑的字段 -->
                      <div v-if="editMode">
                        <p><strong>地址:</strong></p>
                        <a-input
                          v-model:value="item.address"
                          size="small"
                          style="margin-bottom: 8px"
                        />

                        <p><strong>游览时长(分钟):</strong></p>
                        <a-input-number
                          v-model:value="item.visit_duration"
                          :min="10"
                          :max="480"
                          size="small"
                          style="width: 100%; margin-bottom: 8px"
                        />

                        <p><strong>描述:</strong></p>
                        <a-textarea
                          v-model:value="item.description"
                          :rows="2"
                          size="small"
                          style="margin-bottom: 8px"
                        />
                      </div>

                      <!-- 查看模式 -->
                      <div v-else>
                        <p><strong>地址:</strong> {{ item.address }}</p>
                        <p><strong>游览时长:</strong> {{ item.visit_duration }}分钟</p>
                        <p>
                          <strong>描述:</strong>
                          <span class="attraction-desc">{{ item.description }}</span>
                        </p>
                        <p v-if="item.rating">
                          <strong>评分:</strong> {{ item.rating }}⭐
                        </p>
                      </div>
                    </a-card>
                  </a-list-item>
                </template>
              </a-list>

              <!-- 酒店推荐 -->
              <a-divider v-if="day.hotel" orientation="left">🏨 住宿推荐</a-divider>
              <a-card v-if="day.hotel" size="small" class="hotel-card">
                <template #title>
                  <span class="hotel-title">{{ day.hotel.name }}</span>
                </template>
                <a-descriptions :column="2" size="small">
                  <a-descriptions-item label="地址">{{
                    day.hotel.address
                  }}</a-descriptions-item>
                  <a-descriptions-item label="类型">{{
                    day.hotel.type
                  }}</a-descriptions-item>
                  <a-descriptions-item label="价格范围">{{
                    day.hotel.price_range
                  }}</a-descriptions-item>
                  <a-descriptions-item label="评分"
                    >{{ day.hotel.rating }}⭐</a-descriptions-item
                  >
                  <a-descriptions-item label="距离" :span="2">{{
                    day.hotel.distance
                  }}</a-descriptions-item>
                </a-descriptions>
              </a-card>

              <!-- 餐饮安排 -->
              <a-divider orientation="left">🍽️ 餐饮安排</a-divider>
              <a-descriptions :column="1" bordered size="small">
                <a-descriptions-item
                  v-for="meal in day.meals"
                  :key="meal.type"
                  :label="getMealLabel(meal.type)"
                >
                  {{ meal.name }}
                  <span v-if="meal.description"> - {{ meal.description }}</span>
                </a-descriptions-item>
              </a-descriptions>
            </a-collapse-panel>
          </a-collapse>
        </a-card>

        <a-card
          id="weather"
          v-if="tripPlan.weather_info && tripPlan.weather_info.length > 0"
          title="🌤️ 天气信息"
          class="weather-section"
          :bordered="false"
        >
          <!-- 双数据源: 高德4天 + Open-Meteo补齐至16天, 行程更远日期仍无预报, 明确告知用户 -->
          <a-alert
            class="weather-tip"
            type="info"
            show-icon
            message="天气数据来自高德（今日起 4 天）与 Open-Meteo（今日起 16 天）预报合并，仅展示行程日期范围内有预报的日期；更远的日期暂无数据，出行前请再次查询。"
          />
          <a-list :data-source="tripPlan.weather_info" :grid="{ gutter: 16, column: 3 }">
            <template #renderItem="{ item }">
              <a-list-item>
                <a-card size="small" class="weather-card">
                  <div class="weather-date">{{ item.date }}</div>
                  <div class="weather-info-row">
                    <span class="weather-icon">☀️</span>
                    <div>
                      <div class="weather-label">白天</div>
                      <div class="weather-value">
                        {{ item.day_weather }} {{ item.day_temp }}°C
                      </div>
                    </div>
                  </div>
                  <div class="weather-info-row">
                    <span class="weather-icon">🌙</span>
                    <div>
                      <div class="weather-label">夜间</div>
                      <div class="weather-value">
                        {{ item.night_weather }} {{ item.night_temp }}°C
                      </div>
                    </div>
                  </div>
                  <div class="weather-wind">
                    💨 {{ item.wind_direction }} {{ item.wind_power }}
                  </div>
                </a-card>
              </a-list-item>
            </template>
          </a-list>
        </a-card>

        <!-- 行程日期全部超出16天预报窗口时的空态提示 -->
        <a-card
          v-else
          id="weather"
          title="🌤️ 天气信息"
          class="weather-section"
          :bordered="false"
        >
          <a-empty
            description="行程日期超出天气预报范围（高德提供今日起 4 天、Open-Meteo 提供今日起 16 天），出行前请自行查询目的地天气"
          />
        </a-card>
      </div>
    </div>

    <a-empty v-else description="没有找到旅行计划数据">
      <template #image>
        <div style="font-size: 80px">🗺️</div>
      </template>
      <template #description>
        <span style="color: #999">暂无旅行计划数据,请先创建行程</span>
      </template>
      <a-button type="primary" @click="goBack">返回首页创建行程</a-button>
    </a-empty>

    <!-- 回到顶部按钮 -->
    <a-back-top :visibility-height="300">
      <div class="back-top-button">↑</div>
    </a-back-top>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, nextTick, computed } from "vue";
import { useRouter } from "vue-router";
import { message } from "ant-design-vue";
import { DownOutlined } from "@ant-design/icons-vue";
import AMapLoader from "@amap/amap-jsapi-loader";
import html2canvas from "html2canvas";
import jsPDF from "jspdf";
import type { TripPlan } from "@/types";
import { updateHistory } from "@/services/api";

const router = useRouter();
const tripPlan = ref<TripPlan | null>(null);
const editMode = ref(false);
const originalPlan = ref<TripPlan | null>(null);
const attractionPhotos = ref<Record<string, string>>({});
const activeSection = ref("overview");
const activeDays = ref<number[]>([0]); // 默认展开第一天
const historyRecordId = ref<number>(0); // 从历史打开时的记录 id (0=新规划)
let map: any = null;

// 统计所有景点数量
const totalAttractions = computed(() => {
  if (!tripPlan.value) return 0;
  return tripPlan.value.days.reduce((sum, day) => sum + day.attractions.length, 0);
});

// 金额千分位格式化
const formatMoney = (value: number): string => {
  return (value || 0).toLocaleString("zh-CN");
};

onMounted(async () => {
  const data = sessionStorage.getItem("tripPlan");
  if (data) {
    tripPlan.value = JSON.parse(data);
    // 历史打开时记录 id (供编辑保存写回数据库); 新规划则为 0
    historyRecordId.value = Number(sessionStorage.getItem("tripPlanId") || "0");
    // 加载景点图片
    await loadAttractionPhotos();
    // 等待DOM渲染完成后初始化地图
    await nextTick();
    initMap();
  }
});

const goBack = () => {
  router.push("/");
};

// 滚动到指定区域
const scrollToSection = ({ key }: { key: string }) => {
  activeSection.value = key;
  // 每日行程: 先展开对应面板再滚动定位
  if (key.startsWith("day-")) {
    const dayIndex = Number(key.replace("day-", ""));
    activeDays.value = [dayIndex];
    nextTick(() => {
      document
        .getElementById(key)
        ?.scrollIntoView({ behavior: "smooth", block: "start" });
    });
    return;
  }
  document.getElementById(key)?.scrollIntoView({ behavior: "smooth", block: "start" });
};

// 切换编辑模式
const toggleEditMode = () => {
  editMode.value = true;
  // 保存原始数据用于取消编辑
  originalPlan.value = JSON.parse(JSON.stringify(tripPlan.value));
  message.info("进入编辑模式");
};

// 保存修改
const saveChanges = async () => {
  editMode.value = false;
  // 更新sessionStorage (始终保留当前渲染数据)
  if (tripPlan.value) {
    sessionStorage.setItem("tripPlan", JSON.stringify(tripPlan.value));
  }
  // 从历史打开时: 把编辑结果持久化回数据库, 下次打开历史仍是编辑后的内容
  if (historyRecordId.value && tripPlan.value) {
    try {
      await updateHistory(historyRecordId.value, tripPlan.value);
      message.success("修改已保存到历史记录");
    } catch (error: any) {
      message.error(error.message || "保存失败, 修改仅保留在本地");
    }
  } else {
    message.success("修改已保存");
  }

  // 重新初始化地图以反映更改
  if (map) {
    map.destroy();
  }
  nextTick(() => {
    initMap();
  });
};

// 取消编辑
const cancelEdit = () => {
  if (originalPlan.value) {
    tripPlan.value = JSON.parse(JSON.stringify(originalPlan.value));
  }
  editMode.value = false;
  message.info("已取消编辑");
};

// 删除景点
const deleteAttraction = (dayIndex: number, attrIndex: number) => {
  if (!tripPlan.value) return;

  const day = tripPlan.value.days[dayIndex];
  if (day.attractions.length <= 1) {
    message.warning("每天至少需要保留一个景点");
    return;
  }

  day.attractions.splice(attrIndex, 1);
  message.success("景点已删除");
};

// 移动景点顺序
const moveAttraction = (
  dayIndex: number,
  attrIndex: number,
  direction: "up" | "down"
) => {
  if (!tripPlan.value) return;

  const day = tripPlan.value.days[dayIndex];
  const attractions = day.attractions;

  if (direction === "up" && attrIndex > 0) {
    [attractions[attrIndex], attractions[attrIndex - 1]] = [
      attractions[attrIndex - 1],
      attractions[attrIndex],
    ];
  } else if (direction === "down" && attrIndex < attractions.length - 1) {
    [attractions[attrIndex], attractions[attrIndex + 1]] = [
      attractions[attrIndex + 1],
      attractions[attrIndex],
    ];
  }
};

const getMealLabel = (type: string): string => {
  const labels: Record<string, string> = {
    breakfast: "早餐",
    lunch: "午餐",
    dinner: "晚餐",
    snack: "小吃",
  };
  return labels[type] || type;
};

// 后端API地址 (与 services/api.ts 保持一致, 修复旧版硬编码 localhost:8000 导致部署环境拉不到图片)
const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || "http://localhost:8000";

// 加载所有景点图片
const loadAttractionPhotos = async () => {
  if (!tripPlan.value) return;

  const promises: Promise<void>[] = [];

  tripPlan.value.days.forEach((day) => {
    day.attractions.forEach((attraction) => {
      const promise = fetch(
        `${API_BASE_URL}/api/poi/photo?name=${encodeURIComponent(attraction.name)}`
      )
        .then((res) => res.json())
        .then((data) => {
          if (data.success && data.data.photo_url) {
            attractionPhotos.value[attraction.name] = data.data.photo_url;
          }
        })
        .catch((err) => {
          console.error(`获取${attraction.name}图片失败:`, err);
        });

      promises.push(promise);
    });
  });

  await Promise.all(promises);
};

// 信息来源标签颜色: 高德=蓝(真实POI), 知识库=绿(有人工整理详情), AI推荐=橙(需核实)
const sourceTagColor = (src: string): string => {
  if (src.includes("高德")) return "blue";
  if (src.includes("知识库")) return "green";
  return "orange";
};

// 获取景点图片
const getAttractionImage = (name: string, index: number): string => {
  // 如果已加载真实图片,返回真实图片
  if (attractionPhotos.value[name]) {
    return attractionPhotos.value[name];
  }

  // 返回一个纯色占位图(避免跨域问题)
  const colors = [
    { start: "#667eea", end: "#764ba2" },
    { start: "#f093fb", end: "#f5576c" },
    { start: "#4facfe", end: "#00f2fe" },
    { start: "#43e97b", end: "#38f9d7" },
    { start: "#fa709a", end: "#fee140" },
  ];
  const colorIndex = index % colors.length;
  const { start, end } = colors[colorIndex];

  // 使用base64编码避免中文问题
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="400" height="300">
    <defs>
      <linearGradient id="grad${index}" x1="0%" y1="0%" x2="100%" y2="100%">
        <stop offset="0%" style="stop-color:${start};stop-opacity:1" />
        <stop offset="100%" style="stop-color:${end};stop-opacity:1" />
      </linearGradient>
    </defs>
    <rect width="400" height="300" fill="url(#grad${index})"/>
    <text x="50%" y="50%" dominant-baseline="middle" text-anchor="middle" font-family="sans-serif" font-size="24" font-weight="bold" fill="white">${name}</text>
  </svg>`;

  return `data:image/svg+xml;base64,${btoa(unescape(encodeURIComponent(svg)))}`;
};

// 图片加载失败时的处理
const handleImageError = (event: Event) => {
  const img = event.target as HTMLImageElement;
  // 使用灰色占位图
  img.src =
    'data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg" width="400" height="300"%3E%3Crect width="400" height="300" fill="%23f0f0f0"/%3E%3Ctext x="50%25" y="50%25" dominant-baseline="middle" text-anchor="middle" font-family="sans-serif" font-size="18" fill="%23999"%3E图片加载失败%3C/text%3E%3C/svg%3E';
};

// 后端 API 基地址 (与 services/api.ts 保持一致), 导出图片代理用
const API_BASE = import.meta.env.VITE_API_BASE_URL || "http://localhost:8000";

// 把导出容器里的高德 CDN 图片替换为后端代理源, 并等待加载完成。
// 修复导出图片/PDF 照片空白: 高德 CDN 不返回 CORS 头, html2canvas 以
// crossOrigin 方式重新拉图会被浏览器拒绝; 换成带 CORS 的后端代理即可绘制。
const prepareExportImages = async (container: HTMLElement) => {
  const imgs = Array.from(container.querySelectorAll("img"));
  await Promise.all(
    imgs.map((img) => {
      const src = img.getAttribute("src") || "";
      // 跳过: 空src / data URI(地图截图、占位图) / 已代理的图
      if (!src || src.startsWith("data:") || src.includes("/api/poi/image-proxy")) {
        return Promise.resolve();
      }
      return new Promise<void>((resolve) => {
        img.onload = () => resolve();
        img.onerror = () => resolve(); // 代理失败不阻塞导出(该图仍为空白)
        img.src = `${API_BASE}/api/poi/image-proxy?url=${encodeURIComponent(src)}`;
      });
    })
  );
};

// 导出为图片
const exportAsImage = async () => {
  try {
    message.loading({ content: "正在生成图片...", key: "export", duration: 0 });

    const element = document.querySelector(".main-content") as HTMLElement;
    if (!element) {
      throw new Error("未找到内容元素");
    }

    // 创建一个独立的容器
    const exportContainer = document.createElement("div");
    exportContainer.style.width = element.offsetWidth + "px";
    exportContainer.style.backgroundColor = "#f5f7fa";
    exportContainer.style.padding = "20px";

    // 复制所有内容
    exportContainer.innerHTML = element.innerHTML;

    // 处理地图截图 (WebGL canvas 需 preserveDrawingBuffer 才能 toDataURL,
    // 失败时用占位提示替代, 不中断导出)
    const mapContainer = document.getElementById("amap-container");
    if (mapContainer && map) {
      const exportMapContainer = exportContainer.querySelector("#amap-container");
      if (exportMapContainer) {
        try {
          const mapCanvas = mapContainer.querySelector("canvas");
          const mapSnapshot = mapCanvas
            ? mapCanvas.toDataURL("image/png")
            : "";
          exportMapContainer.innerHTML = mapSnapshot
            ? `<img src="${mapSnapshot}" style="width:100%;height:100%;object-fit:cover;" />`
            : `<div style="display:flex;align-items:center;justify-content:center;height:100%;background:#e8eaef;color:#888;">地图截图不可用</div>`;
        } catch (err) {
          console.error("地图截图失败:", err);
          exportMapContainer.innerHTML = `<div style="display:flex;align-items:center;justify-content:center;height:100%;background:#e8eaef;color:#888;">地图截图不可用</div>`;
        }
      }
    }

    // 移除所有ant-card类,替换为纯div
    const cards = exportContainer.querySelectorAll(".ant-card");
    cards.forEach((card) => {
      const cardEl = card as HTMLElement;
      try {
        cardEl.className = ""; // 移除所有类
        cardEl.style.setProperty("background-color", "#ffffff");
        cardEl.style.setProperty("border-radius", "12px");
        cardEl.style.setProperty("box-shadow", "0 4px 12px rgba(0, 0, 0, 0.1)");
        cardEl.style.setProperty("margin-bottom", "20px");
        cardEl.style.setProperty("overflow", "hidden");
      } catch (err) {
        console.error("设置卡片样式失败:", err);
      }
    });

    // 处理卡片头部
    const cardHeads = exportContainer.querySelectorAll(".ant-card-head");
    cardHeads.forEach((head) => {
      const headEl = head as HTMLElement;
      try {
        headEl.style.setProperty("background-color", "#667eea");
        headEl.style.setProperty("color", "#ffffff");
        headEl.style.setProperty("padding", "16px 24px");
        headEl.style.setProperty("font-size", "18px");
        headEl.style.setProperty("font-weight", "600");
      } catch (err) {
        console.error("设置卡片头部样式失败:", err);
      }
    });

    // 处理卡片内容
    const cardBodies = exportContainer.querySelectorAll(".ant-card-body");
    cardBodies.forEach((body) => {
      const bodyEl = body as HTMLElement;
      bodyEl.style.setProperty("background-color", "#ffffff");
      bodyEl.style.setProperty("padding", "24px");
    });

    // 处理酒店卡片头部
    const hotelCards = exportContainer.querySelectorAll(".hotel-card");
    hotelCards.forEach((card) => {
      const head = card.querySelector(".ant-card-head") as HTMLElement;
      if (head) {
        head.style.setProperty("background-color", "#1976d2");
      }
      (card as HTMLElement).style.setProperty("background-color", "#e3f2fd");
    });

    // 处理天气卡片
    const weatherCards = exportContainer.querySelectorAll(".weather-card");
    weatherCards.forEach((card) => {
      (card as HTMLElement).style.setProperty("background-color", "#e0f7fa");
    });

    // 处理预算总计
    const budgetTotal = exportContainer.querySelector(".budget-total");
    if (budgetTotal) {
      const el = budgetTotal as HTMLElement;
      el.style.setProperty("background-color", "#667eea");
      el.style.setProperty("color", "#ffffff");
      el.style.setProperty("padding", "20px");
      el.style.setProperty("border-radius", "12px");
      el.style.setProperty("margin-bottom", "20px");
    }

    // 处理预算项
    const budgetItems = exportContainer.querySelectorAll(".budget-item");
    budgetItems.forEach((item) => {
      const el = item as HTMLElement;
      el.style.setProperty("background-color", "#f5f7fa");
      el.style.setProperty("padding", "16px");
      el.style.setProperty("border-radius", "8px");
      el.style.setProperty("margin-bottom", "12px");
    });

    // 添加到body(隐藏)
    exportContainer.style.position = "absolute";
    exportContainer.style.left = "-9999px";
    document.body.appendChild(exportContainer);

    // 照片换后端代理源并等待加载, 修复导出空白
    await prepareExportImages(exportContainer);

    const canvas = await html2canvas(exportContainer, {
      backgroundColor: "#f5f7fa",
      scale: 2,
      logging: false,
      useCORS: true,
      allowTaint: true,
    });

    // 移除容器
    document.body.removeChild(exportContainer);

    // 转换为图片并下载
    const link = document.createElement("a");
    link.download = `旅行计划_${tripPlan.value?.city}_${new Date().getTime()}.png`;
    link.href = canvas.toDataURL("image/png");
    link.click();

    message.success({ content: "图片导出成功!", key: "export" });
  } catch (error: any) {
    console.error("导出图片失败:", error);
    message.error({ content: `导出图片失败: ${error.message}`, key: "export" });
  }
};

// 导出为PDF
const exportAsPDF = async () => {
  try {
    message.loading({ content: "正在生成PDF...", key: "export", duration: 0 });

    const element = document.querySelector(".main-content") as HTMLElement;
    if (!element) {
      throw new Error("未找到内容元素");
    }

    // 创建一个独立的容器
    const exportContainer = document.createElement("div");
    exportContainer.style.width = element.offsetWidth + "px";
    exportContainer.style.backgroundColor = "#f5f7fa";
    exportContainer.style.padding = "20px";

    // 复制所有内容
    exportContainer.innerHTML = element.innerHTML;

    // 处理地图截图 (WebGL canvas 需 preserveDrawingBuffer 才能 toDataURL,
    // 失败时用占位提示替代, 不中断导出)
    const mapContainer = document.getElementById("amap-container");
    if (mapContainer && map) {
      const exportMapContainer = exportContainer.querySelector("#amap-container");
      if (exportMapContainer) {
        try {
          const mapCanvas = mapContainer.querySelector("canvas");
          const mapSnapshot = mapCanvas
            ? mapCanvas.toDataURL("image/png")
            : "";
          exportMapContainer.innerHTML = mapSnapshot
            ? `<img src="${mapSnapshot}" style="width:100%;height:100%;object-fit:cover;" />`
            : `<div style="display:flex;align-items:center;justify-content:center;height:100%;background:#e8eaef;color:#888;">地图截图不可用</div>`;
        } catch (err) {
          console.error("地图截图失败:", err);
          exportMapContainer.innerHTML = `<div style="display:flex;align-items:center;justify-content:center;height:100%;background:#e8eaef;color:#888;">地图截图不可用</div>`;
        }
      }
    }

    // 移除所有ant-card类,替换为纯div
    const cards = exportContainer.querySelectorAll(".ant-card");
    cards.forEach((card) => {
      const cardEl = card as HTMLElement;
      try {
        cardEl.className = "";
        cardEl.style.setProperty("background-color", "#ffffff");
        cardEl.style.setProperty("border-radius", "12px");
        cardEl.style.setProperty("box-shadow", "0 4px 12px rgba(0, 0, 0, 0.1)");
        cardEl.style.setProperty("margin-bottom", "20px");
        cardEl.style.setProperty("overflow", "hidden");
      } catch (err) {
        console.error("设置卡片样式失败:", err);
      }
    });

    // 处理卡片头部
    const cardHeads = exportContainer.querySelectorAll(".ant-card-head");
    cardHeads.forEach((head) => {
      const headEl = head as HTMLElement;
      try {
        headEl.style.setProperty("background-color", "#667eea");
        headEl.style.setProperty("color", "#ffffff");
        headEl.style.setProperty("padding", "16px 24px");
        headEl.style.setProperty("font-size", "18px");
        headEl.style.setProperty("font-weight", "600");
      } catch (err) {
        console.error("设置卡片头部样式失败:", err);
      }
    });

    // 处理卡片内容
    const cardBodies = exportContainer.querySelectorAll(".ant-card-body");
    cardBodies.forEach((body) => {
      const bodyEl = body as HTMLElement;
      bodyEl.style.setProperty("background-color", "#ffffff");
      bodyEl.style.setProperty("padding", "24px");
    });

    // 处理酒店卡片头部
    const hotelCards = exportContainer.querySelectorAll(".hotel-card");
    hotelCards.forEach((card) => {
      const head = card.querySelector(".ant-card-head") as HTMLElement;
      if (head) {
        head.style.setProperty("background-color", "#1976d2");
      }
      (card as HTMLElement).style.setProperty("background-color", "#e3f2fd");
    });

    // 处理天气卡片
    const weatherCards = exportContainer.querySelectorAll(".weather-card");
    weatherCards.forEach((card) => {
      (card as HTMLElement).style.setProperty("background-color", "#e0f7fa");
    });

    // 处理预算总计
    const budgetTotal = exportContainer.querySelector(".budget-total");
    if (budgetTotal) {
      const el = budgetTotal as HTMLElement;
      el.style.setProperty("background-color", "#667eea");
      el.style.setProperty("color", "#ffffff");
      el.style.setProperty("padding", "20px");
      el.style.setProperty("border-radius", "12px");
      el.style.setProperty("margin-bottom", "20px");
    }

    // 处理预算项
    const budgetItems = exportContainer.querySelectorAll(".budget-item");
    budgetItems.forEach((item) => {
      const el = item as HTMLElement;
      el.style.setProperty("background-color", "#f5f7fa");
      el.style.setProperty("padding", "16px");
      el.style.setProperty("border-radius", "8px");
      el.style.setProperty("margin-bottom", "12px");
    });

    // 添加到body(隐藏)
    exportContainer.style.position = "absolute";
    exportContainer.style.left = "-9999px";
    document.body.appendChild(exportContainer);

    // 照片换后端代理源并等待加载, 修复导出空白
    await prepareExportImages(exportContainer);

    const canvas = await html2canvas(exportContainer, {
      backgroundColor: "#f5f7fa",
      scale: 2,
      logging: false,
      useCORS: true,
      allowTaint: true,
    });

    // 移除容器
    document.body.removeChild(exportContainer);

    const imgData = canvas.toDataURL("image/png");
    const pdf = new jsPDF({
      orientation: "portrait",
      unit: "mm",
      format: "a4",
    });

    const imgWidth = 210; // A4宽度(mm)
    const imgHeight = (canvas.height * imgWidth) / canvas.width;

    // 如果内容高度超过一页,分页处理
    let heightLeft = imgHeight;
    let position = 0;

    pdf.addImage(imgData, "PNG", 0, position, imgWidth, imgHeight);
    heightLeft -= 297; // A4高度

    while (heightLeft > 0) {
      position = heightLeft - imgHeight;
      pdf.addPage();
      pdf.addImage(imgData, "PNG", 0, position, imgWidth, imgHeight);
      heightLeft -= 297;
    }

    pdf.save(`旅行计划_${tripPlan.value?.city}_${new Date().getTime()}.pdf`);

    message.success({ content: "PDF导出成功!", key: "export" });
  } catch (error: any) {
    console.error("导出PDF失败:", error);
    message.error({ content: `导出PDF失败: ${error.message}`, key: "export" });
  }
};

// 初始化地图
const initMap = async () => {
  try {
    const AMap = await AMapLoader.load({
      key: import.meta.env.VITE_AMAP_WEB_JS_KEY, // 高德地图Web端(JS API) Key
      version: "2.0",
      plugins: ["AMap.Marker", "AMap.Polyline", "AMap.InfoWindow"],
    });

    // 创建地图实例
    // 中心点: 取行程中第一个有效景点坐标(修复旧版bug: 硬编码北京中心,
    // 导致成都等无坐标行程的地图显示北京); 无任何有效坐标时才回退北京并提示
    const mapCenter = getMapCenter();
    map = new AMap.Map("amap-container", {
      zoom: 12,
      center: mapCenter.center,
      viewMode: "3D",
      // WebGL 默认在合成后清空绘图缓冲区, 导出时 canvas.toDataURL() 会得到空白图;
      // 开启 preserveDrawingBuffer 保留缓冲区, 地图截图才能进导出的图片/PDF
      WebGLParams: { preserveDrawingBuffer: true },
    });
    if (!mapCenter.found) {
      message.warning("行程景点缺少有效坐标, 地图无法定位到目的地城市");
    }

    // 添加景点标记
    addAttractionMarkers(AMap);

    message.success("地图加载成功");
  } catch (error) {
    console.error("地图加载失败:", error);
    message.error("地图加载失败");
  }
};

// 计算地图初始中心: 第一个有效景点坐标 > 酒店坐标 > 默认北京(仅兜底)
const getMapCenter = (): { center: [number, number]; found: boolean } => {
  const DEFAULT_CENTER: [number, number] = [116.397128, 39.916527];
  if (!tripPlan.value) return { center: DEFAULT_CENTER, found: false };

  for (const day of tripPlan.value.days) {
    for (const attr of day.attractions) {
      const loc = attr.location;
      if (loc && loc.longitude && loc.latitude) {
        return { center: [loc.longitude, loc.latitude], found: true };
      }
    }
    const hotelLoc = day.hotel?.location;
    if (hotelLoc && hotelLoc.longitude && hotelLoc.latitude) {
      return { center: [hotelLoc.longitude, hotelLoc.latitude], found: true };
    }
  }
  return { center: DEFAULT_CENTER, found: false };
};

// 添加景点标记
const addAttractionMarkers = (AMap: any) => {
  if (!tripPlan.value) return;

  const markers: any[] = [];
  const allAttractions: any[] = [];

  // 收集所有景点
  tripPlan.value.days.forEach((day, dayIndex) => {
    day.attractions.forEach((attraction, attrIndex) => {
      if (
        attraction.location &&
        attraction.location.longitude &&
        attraction.location.latitude
      ) {
        allAttractions.push({
          ...attraction,
          dayIndex,
          attrIndex,
        });
      }
    });
  });

  // 创建标记
  allAttractions.forEach((attraction, index) => {
    const marker = new AMap.Marker({
      position: [attraction.location.longitude, attraction.location.latitude],
      title: attraction.name,
      label: {
        content: `<div style="background: #4CAF50; color: white; padding: 4px 8px; border-radius: 4px; font-size: 12px;">${
          index + 1
        }</div>`,
        offset: new AMap.Pixel(0, -30),
      },
    });

    // 创建信息窗口
    const infoWindow = new AMap.InfoWindow({
      content: `
        <div style="padding: 10px;">
          <h4 style="margin: 0 0 8px 0;">${attraction.name}</h4>
          <p style="margin: 4px 0;"><strong>地址:</strong> ${attraction.address}</p>
          <p style="margin: 4px 0;"><strong>游览时长:</strong> ${
            attraction.visit_duration
          }分钟</p>
          <p style="margin: 4px 0;"><strong>描述:</strong> ${attraction.description}</p>
          <p style="margin: 4px 0; color: #1890ff;"><strong>第${
            attraction.dayIndex + 1
          }天 景点${attraction.attrIndex + 1}</strong></p>
        </div>
      `,
      offset: new AMap.Pixel(0, -30),
    });

    // 点击标记显示信息窗口
    marker.on("click", () => {
      infoWindow.open(map, marker.getPosition());
    });

    markers.push(marker);
  });

  // 添加标记到地图
  map.add(markers);

  // 自动调整视野以包含所有标记
  if (allAttractions.length > 0) {
    map.setFitView(markers);
  }

  // 绘制路线
  drawRoutes(AMap, allAttractions);
};

// 绘制路线
const drawRoutes = (AMap: any, attractions: any[]) => {
  if (attractions.length < 2) return;

  // 按天分组绘制路线
  const dayGroups: any = {};
  attractions.forEach((attr) => {
    if (!dayGroups[attr.dayIndex]) {
      dayGroups[attr.dayIndex] = [];
    }
    dayGroups[attr.dayIndex].push(attr);
  });

  // 为每天的景点绘制路线
  Object.values(dayGroups).forEach((dayAttractions: any) => {
    if (dayAttractions.length < 2) return;

    const path = dayAttractions.map((attr: any) => [
      attr.location.longitude,
      attr.location.latitude,
    ]);

    const polyline = new AMap.Polyline({
      path: path,
      strokeColor: "#1890ff",
      strokeWeight: 4,
      strokeOpacity: 0.8,
      strokeStyle: "solid",
      showDir: true, // 显示方向箭头
    });

    map.add(polyline);
  });
};
</script>

<style scoped>
.result-container {
  min-height: 100vh;
  background: transparent;
  padding: 40px 20px;
}

.page-header {
  max-width: 1200px;
  margin: 0 auto 30px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  animation: fadeInDown 0.6s ease-out;
}

.back-button {
  border-radius: 8px;
  font-weight: 500;
}

/* 内容布局 */
.content-wrapper {
  max-width: 1400px;
  margin: 0 auto;
  display: flex;
  gap: 24px;
}

.side-nav {
  width: 240px;
  flex-shrink: 0;
}

.side-nav :deep(.ant-menu) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.93);
  backdrop-filter: blur(16px) saturate(140%);
  border: 1px solid rgba(255, 255, 255, 0.5);
  box-shadow: 0 12px 36px rgba(2, 6, 23, 0.35);
}

.side-nav :deep(.ant-menu-item) {
  margin: 4px 8px;
  border-radius: 8px;
  transition: all 0.3s ease;
}

.side-nav :deep(.ant-menu-item-selected) {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
}

.side-nav :deep(.ant-menu-item:hover) {
  background: rgba(102, 126, 234, 0.1);
}

.main-content {
  flex: 1;
  min-width: 0;
}

/* 景点图片样式 */
.attraction-image-wrapper {
  position: relative;
  margin-bottom: 12px;
  border-radius: 8px;
  overflow: hidden;
}

/* 景点描述: 保留换行, 展示知识库多行详情 (门票/开放时间/交通/避坑) */
.attraction-desc {
  white-space: pre-line;
  color: #666;
  font-size: 13px;
  line-height: 1.6;
}

/* 卡片标题: 景点名 + 来源标签同行展示, 标签缩小避免喧宾夺主 */
.attraction-title {
  display: inline-flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 4px;
}

.source-tag {
  font-size: 11px;
  line-height: 18px;
  padding: 0 6px;
  margin-inline-end: 0;
  font-weight: normal;
  color: rgba(0, 0, 0, 0.88);
  font-weight: 700;
}

.attraction-image {
  width: 100%;
  height: 200px;
  object-fit: cover;
  transition: transform 0.3s ease;
}

.attraction-image-wrapper:hover .attraction-image {
  transform: scale(1.05);
}

.attraction-badge {
  position: absolute;
  top: 12px;
  left: 12px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  width: 36px;
  height: 36px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: bold;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2);
}

.badge-number {
  font-size: 18px;
}

.price-tag {
  position: absolute;
  top: 12px;
  right: 12px;
  background: rgba(255, 77, 79, 0.9);
  color: white;
  padding: 4px 12px;
  border-radius: 12px;
  font-weight: bold;
  font-size: 14px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2);
}

/* 天气卡片样式 */
.weather-card {
  background: linear-gradient(135deg, #e0f7fa 0%, #b2ebf2 100%);
  border: none !important;
  transition: all 0.3s ease;
}

.weather-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 8px 16px rgba(0, 0, 0, 0.15);
}

.weather-date {
  font-size: 16px;
  font-weight: bold;
  color: #00796b;
  margin-bottom: 12px;
  text-align: center;
}

.weather-info-row {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 8px;
}

.weather-icon {
  font-size: 24px;
}

.weather-label {
  font-size: 12px;
  color: #666;
}

.weather-value {
  font-size: 16px;
  font-weight: 600;
  color: #00796b;
}

.weather-wind {
  margin-top: 8px;
  padding-top: 8px;
  border-top: 1px solid rgba(0, 121, 107, 0.2);
  text-align: center;
  color: #00796b;
  font-size: 14px;
}

/* 回到顶部按钮 */
.back-top-button {
  width: 50px;
  height: 50px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 24px;
  font-weight: bold;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
  cursor: pointer;
  transition: all 0.3s ease;
}

.back-top-button:hover {
  transform: scale(1.1);
  box-shadow: 0 6px 16px rgba(0, 0, 0, 0.4);
}

/* 酒店卡片样式 */
.hotel-card {
  background: linear-gradient(135deg, #e3f2fd 0%, #bbdefb 100%);
  border: none !important;
}

.hotel-card :deep(.ant-card-head) {
  background: linear-gradient(135deg, #1976d2 0%, #1565c0 100%);
}

.hotel-title {
  color: white !important;
  font-weight: 600;
}

/* 顶部信息区布局 */
.top-info-section {
  display: flex;
  gap: 20px;
  margin-bottom: 20px;
}

.left-info {
  flex: 0 0 400px;
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.right-map {
  flex: 1;
}

/* 行程概览卡片 */
.overview-card {
  height: fit-content;
}

.overview-days {
  color: #667eea;
  font-weight: 600;
  font-size: 13px;
  background: rgba(102, 126, 234, 0.1);
  padding: 4px 12px;
  border-radius: 12px;
}

.overview-content {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

/* 概览统计 */
.overview-stats {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 10px;
  margin: 4px 0;
}

.stat-box {
  text-align: center;
  padding: 12px 4px;
  background: linear-gradient(135deg, #f5f7fa 0%, #ffffff 100%);
  border-radius: 10px;
  border: 1px solid #e8e8e8;
}

.stat-num {
  font-size: 20px;
  font-weight: 700;
  color: #667eea;
}

.stat-label {
  font-size: 12px;
  color: #999;
  margin-top: 2px;
}

.info-item {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.info-label {
  font-size: 14px;
  font-weight: 600;
  color: #666;
}

.info-value {
  font-size: 15px;
  color: #333;
  line-height: 1.6;
}

/* 预算卡片 */
.budget-card {
  height: fit-content;
}

.budget-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 16px;
  margin-bottom: 16px;
}

.budget-item {
  text-align: center;
  padding: 12px;
  background: linear-gradient(135deg, #f5f7fa 0%, #ffffff 100%);
  border-radius: 8px;
  border: 1px solid #e8e8e8;
}

.budget-label {
  font-size: 13px;
  color: #666;
  margin-bottom: 8px;
}

.budget-value {
  font-size: 20px;
  font-weight: 700;
  color: #1890ff;
}

.budget-total {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 16px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  border-radius: 8px;
  color: white;
}

.total-label {
  font-size: 16px;
  font-weight: 600;
}

.total-value {
  font-size: 28px;
  font-weight: 700;
}

/* 地图卡片 */
.map-card {
  height: 100%;
  min-height: 500px;
}

.map-card :deep(.ant-card-body) {
  height: calc(100% - 57px);
  padding: 0;
}

/* 每日行程卡片 */
.days-card {
  margin-top: 20px;
}

/* 天气信息卡片 */
.weather-section {
  margin-top: 20px;
}

/* 天气数据说明提示 */
.weather-tip {
  margin-bottom: 16px;
}

/* 降级数据警告横幅 */
.fallback-alert {
  max-width: 1400px;
  margin: 0 auto 20px;
  border-radius: 8px;
}

.day-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  width: 100%;
}

.day-title {
  font-size: 18px;
  font-weight: 600;
  color: #333;
}

.day-date {
  font-size: 14px;
  color: #999;
}

.day-info {
  margin-bottom: 20px;
  padding: 16px;
  background: linear-gradient(135deg, #f5f7fa 0%, #ffffff 100%);
  border-radius: 8px;
  border: 1px solid #e8e8e8;
}

.info-row {
  display: flex;
  gap: 12px;
  margin-bottom: 8px;
}

.info-row:last-child {
  margin-bottom: 0;
}

.info-row .label {
  font-weight: 600;
  color: #666;
  min-width: 100px;
}

.info-row .value {
  color: #333;
  flex: 1;
}

/* 卡片样式优化 */
:deep(.ant-card) {
  border-radius: 12px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
  margin-bottom: 20px;
  transition: all 0.3s ease;
  animation: fadeInUp 0.6s ease-out;
}

:deep(.ant-card:hover) {
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.12);
}

:deep(.ant-card-head) {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white !important;
  border-radius: 12px 12px 0 0;
  font-weight: 600;
}

:deep(.ant-card-head-title) {
  color: white !important;
  font-size: 18px;
}

/* Collapse样式 */
:deep(.ant-collapse) {
  border: none;
  background: transparent;
}

:deep(.ant-collapse-item) {
  margin-bottom: 16px;
  border: 1px solid #e8e8e8;
  border-radius: 12px;
  overflow: hidden;
}

:deep(.ant-collapse-header) {
  background: linear-gradient(135deg, #f5f7fa 0%, #ffffff 100%);
  padding: 16px 20px !important;
  font-weight: 600;
}

:deep(.ant-collapse-content) {
  border-top: 1px solid #e8e8e8;
}

:deep(.ant-collapse-content-box) {
  padding: 20px;
}

/* 统计卡片样式 */
:deep(.ant-statistic-title) {
  font-size: 14px;
  color: #666;
  margin-bottom: 8px;
}

:deep(.ant-statistic-content) {
  font-size: 24px;
  font-weight: 600;
  color: #1890ff;
}

/* 景点卡片样式 */
:deep(.ant-list-item) {
  transition: all 0.3s ease;
}

:deep(.ant-list-item:hover) {
  transform: scale(1.02);
}

/* 动画 */
@keyframes fadeInDown {
  from {
    opacity: 0;
    transform: translateY(-20px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

@keyframes fadeInUp {
  from {
    opacity: 0;
    transform: translateY(20px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

/* 响应式设计 */
@media (max-width: 768px) {
  .result-container {
    padding: 20px 10px;
  }

  .page-header {
    flex-direction: column;
    gap: 16px;
  }
}
</style>
