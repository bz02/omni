"use strict";
/*
 * ATTENTION: An "eval-source-map" devtool has been used.
 * This devtool is neither made for production nor for readable output files.
 * It uses "eval()" calls to create a separate source file with attached SourceMaps in the browser devtools.
 * If you are trying to read the output file, select a different devtool (https://webpack.js.org/configuration/devtool/)
 * or disable the default devtool with "devtool: false".
 * If you are looking for production-ready output files, see mode: "production" (https://webpack.js.org/configuration/mode/).
 */
(() => {
var exports = {};
exports.id = "app/api/tarot/route";
exports.ids = ["app/api/tarot/route"];
exports.modules = {

/***/ "@prisma/client":
/*!*********************************!*\
  !*** external "@prisma/client" ***!
  \*********************************/
/***/ ((module) => {

module.exports = require("@prisma/client");

/***/ }),

/***/ "bcrypt":
/*!*************************!*\
  !*** external "bcrypt" ***!
  \*************************/
/***/ ((module) => {

module.exports = require("bcrypt");

/***/ }),

/***/ "../../client/components/action-async-storage.external":
/*!*******************************************************************************!*\
  !*** external "next/dist/client/components/action-async-storage.external.js" ***!
  \*******************************************************************************/
/***/ ((module) => {

module.exports = require("next/dist/client/components/action-async-storage.external.js");

/***/ }),

/***/ "../../client/components/request-async-storage.external":
/*!********************************************************************************!*\
  !*** external "next/dist/client/components/request-async-storage.external.js" ***!
  \********************************************************************************/
/***/ ((module) => {

module.exports = require("next/dist/client/components/request-async-storage.external.js");

/***/ }),

/***/ "../../client/components/static-generation-async-storage.external":
/*!******************************************************************************************!*\
  !*** external "next/dist/client/components/static-generation-async-storage.external.js" ***!
  \******************************************************************************************/
/***/ ((module) => {

module.exports = require("next/dist/client/components/static-generation-async-storage.external.js");

/***/ }),

/***/ "next/dist/compiled/next-server/app-page.runtime.dev.js":
/*!*************************************************************************!*\
  !*** external "next/dist/compiled/next-server/app-page.runtime.dev.js" ***!
  \*************************************************************************/
/***/ ((module) => {

module.exports = require("next/dist/compiled/next-server/app-page.runtime.dev.js");

/***/ }),

/***/ "next/dist/compiled/next-server/app-route.runtime.dev.js":
/*!**************************************************************************!*\
  !*** external "next/dist/compiled/next-server/app-route.runtime.dev.js" ***!
  \**************************************************************************/
/***/ ((module) => {

module.exports = require("next/dist/compiled/next-server/app-route.runtime.dev.js");

/***/ }),

/***/ "assert":
/*!*************************!*\
  !*** external "assert" ***!
  \*************************/
/***/ ((module) => {

module.exports = require("assert");

/***/ }),

/***/ "buffer":
/*!*************************!*\
  !*** external "buffer" ***!
  \*************************/
/***/ ((module) => {

module.exports = require("buffer");

/***/ }),

/***/ "crypto":
/*!*************************!*\
  !*** external "crypto" ***!
  \*************************/
/***/ ((module) => {

module.exports = require("crypto");

/***/ }),

/***/ "events":
/*!*************************!*\
  !*** external "events" ***!
  \*************************/
/***/ ((module) => {

module.exports = require("events");

/***/ }),

/***/ "http":
/*!***********************!*\
  !*** external "http" ***!
  \***********************/
/***/ ((module) => {

module.exports = require("http");

/***/ }),

/***/ "https":
/*!************************!*\
  !*** external "https" ***!
  \************************/
/***/ ((module) => {

module.exports = require("https");

/***/ }),

/***/ "querystring":
/*!******************************!*\
  !*** external "querystring" ***!
  \******************************/
/***/ ((module) => {

module.exports = require("querystring");

/***/ }),

/***/ "url":
/*!**********************!*\
  !*** external "url" ***!
  \**********************/
/***/ ((module) => {

module.exports = require("url");

/***/ }),

/***/ "util":
/*!***********************!*\
  !*** external "util" ***!
  \***********************/
/***/ ((module) => {

module.exports = require("util");

/***/ }),

/***/ "zlib":
/*!***********************!*\
  !*** external "zlib" ***!
  \***********************/
/***/ ((module) => {

module.exports = require("zlib");

/***/ }),

/***/ "(rsc)/./node_modules/next/dist/build/webpack/loaders/next-app-loader.js?name=app%2Fapi%2Ftarot%2Froute&page=%2Fapi%2Ftarot%2Froute&appPaths=&pagePath=private-next-app-dir%2Fapi%2Ftarot%2Froute.ts&appDir=%2FUsers%2Fxiaobozhang%2FDocuments%2FGitHub%2Fomni%2Fweb%2Fapp&pageExtensions=tsx&pageExtensions=ts&pageExtensions=jsx&pageExtensions=js&rootDir=%2FUsers%2Fxiaobozhang%2FDocuments%2FGitHub%2Fomni%2Fweb&isDev=true&tsconfigPath=tsconfig.json&basePath=&assetPrefix=&nextConfigOutput=&preferredRegion=&middlewareConfig=e30%3D!":
/*!***********************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************!*\
  !*** ./node_modules/next/dist/build/webpack/loaders/next-app-loader.js?name=app%2Fapi%2Ftarot%2Froute&page=%2Fapi%2Ftarot%2Froute&appPaths=&pagePath=private-next-app-dir%2Fapi%2Ftarot%2Froute.ts&appDir=%2FUsers%2Fxiaobozhang%2FDocuments%2FGitHub%2Fomni%2Fweb%2Fapp&pageExtensions=tsx&pageExtensions=ts&pageExtensions=jsx&pageExtensions=js&rootDir=%2FUsers%2Fxiaobozhang%2FDocuments%2FGitHub%2Fomni%2Fweb&isDev=true&tsconfigPath=tsconfig.json&basePath=&assetPrefix=&nextConfigOutput=&preferredRegion=&middlewareConfig=e30%3D! ***!
  \***********************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

eval("__webpack_require__.r(__webpack_exports__);\n/* harmony export */ __webpack_require__.d(__webpack_exports__, {\n/* harmony export */   originalPathname: () => (/* binding */ originalPathname),\n/* harmony export */   patchFetch: () => (/* binding */ patchFetch),\n/* harmony export */   requestAsyncStorage: () => (/* binding */ requestAsyncStorage),\n/* harmony export */   routeModule: () => (/* binding */ routeModule),\n/* harmony export */   serverHooks: () => (/* binding */ serverHooks),\n/* harmony export */   staticGenerationAsyncStorage: () => (/* binding */ staticGenerationAsyncStorage)\n/* harmony export */ });\n/* harmony import */ var next_dist_server_future_route_modules_app_route_module_compiled__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! next/dist/server/future/route-modules/app-route/module.compiled */ \"(rsc)/./node_modules/next/dist/server/future/route-modules/app-route/module.compiled.js\");\n/* harmony import */ var next_dist_server_future_route_modules_app_route_module_compiled__WEBPACK_IMPORTED_MODULE_0___default = /*#__PURE__*/__webpack_require__.n(next_dist_server_future_route_modules_app_route_module_compiled__WEBPACK_IMPORTED_MODULE_0__);\n/* harmony import */ var next_dist_server_future_route_kind__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! next/dist/server/future/route-kind */ \"(rsc)/./node_modules/next/dist/server/future/route-kind.js\");\n/* harmony import */ var next_dist_server_lib_patch_fetch__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! next/dist/server/lib/patch-fetch */ \"(rsc)/./node_modules/next/dist/server/lib/patch-fetch.js\");\n/* harmony import */ var next_dist_server_lib_patch_fetch__WEBPACK_IMPORTED_MODULE_2___default = /*#__PURE__*/__webpack_require__.n(next_dist_server_lib_patch_fetch__WEBPACK_IMPORTED_MODULE_2__);\n/* harmony import */ var _Users_xiaobozhang_Documents_GitHub_omni_web_app_api_tarot_route_ts__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! ./app/api/tarot/route.ts */ \"(rsc)/./app/api/tarot/route.ts\");\n\n\n\n\n// We inject the nextConfigOutput here so that we can use them in the route\n// module.\nconst nextConfigOutput = \"\"\nconst routeModule = new next_dist_server_future_route_modules_app_route_module_compiled__WEBPACK_IMPORTED_MODULE_0__.AppRouteRouteModule({\n    definition: {\n        kind: next_dist_server_future_route_kind__WEBPACK_IMPORTED_MODULE_1__.RouteKind.APP_ROUTE,\n        page: \"/api/tarot/route\",\n        pathname: \"/api/tarot\",\n        filename: \"route\",\n        bundlePath: \"app/api/tarot/route\"\n    },\n    resolvedPagePath: \"/Users/xiaobozhang/Documents/GitHub/omni/web/app/api/tarot/route.ts\",\n    nextConfigOutput,\n    userland: _Users_xiaobozhang_Documents_GitHub_omni_web_app_api_tarot_route_ts__WEBPACK_IMPORTED_MODULE_3__\n});\n// Pull out the exports that we need to expose from the module. This should\n// be eliminated when we've moved the other routes to the new format. These\n// are used to hook into the route.\nconst { requestAsyncStorage, staticGenerationAsyncStorage, serverHooks } = routeModule;\nconst originalPathname = \"/api/tarot/route\";\nfunction patchFetch() {\n    return (0,next_dist_server_lib_patch_fetch__WEBPACK_IMPORTED_MODULE_2__.patchFetch)({\n        serverHooks,\n        staticGenerationAsyncStorage\n    });\n}\n\n\n//# sourceMappingURL=app-route.js.map//# sourceURL=[module]\n//# sourceMappingURL=data:application/json;charset=utf-8;base64,eyJ2ZXJzaW9uIjozLCJmaWxlIjoiKHJzYykvLi9ub2RlX21vZHVsZXMvbmV4dC9kaXN0L2J1aWxkL3dlYnBhY2svbG9hZGVycy9uZXh0LWFwcC1sb2FkZXIuanM/bmFtZT1hcHAlMkZhcGklMkZ0YXJvdCUyRnJvdXRlJnBhZ2U9JTJGYXBpJTJGdGFyb3QlMkZyb3V0ZSZhcHBQYXRocz0mcGFnZVBhdGg9cHJpdmF0ZS1uZXh0LWFwcC1kaXIlMkZhcGklMkZ0YXJvdCUyRnJvdXRlLnRzJmFwcERpcj0lMkZVc2VycyUyRnhpYW9ib3poYW5nJTJGRG9jdW1lbnRzJTJGR2l0SHViJTJGb21uaSUyRndlYiUyRmFwcCZwYWdlRXh0ZW5zaW9ucz10c3gmcGFnZUV4dGVuc2lvbnM9dHMmcGFnZUV4dGVuc2lvbnM9anN4JnBhZ2VFeHRlbnNpb25zPWpzJnJvb3REaXI9JTJGVXNlcnMlMkZ4aWFvYm96aGFuZyUyRkRvY3VtZW50cyUyRkdpdEh1YiUyRm9tbmklMkZ3ZWImaXNEZXY9dHJ1ZSZ0c2NvbmZpZ1BhdGg9dHNjb25maWcuanNvbiZiYXNlUGF0aD0mYXNzZXRQcmVmaXg9Jm5leHRDb25maWdPdXRwdXQ9JnByZWZlcnJlZFJlZ2lvbj0mbWlkZGxld2FyZUNvbmZpZz1lMzAlM0QhIiwibWFwcGluZ3MiOiI7Ozs7Ozs7Ozs7Ozs7OztBQUFzRztBQUN2QztBQUNjO0FBQ21CO0FBQ2hHO0FBQ0E7QUFDQTtBQUNBLHdCQUF3QixnSEFBbUI7QUFDM0M7QUFDQSxjQUFjLHlFQUFTO0FBQ3ZCO0FBQ0E7QUFDQTtBQUNBO0FBQ0EsS0FBSztBQUNMO0FBQ0E7QUFDQSxZQUFZO0FBQ1osQ0FBQztBQUNEO0FBQ0E7QUFDQTtBQUNBLFFBQVEsaUVBQWlFO0FBQ3pFO0FBQ0E7QUFDQSxXQUFXLDRFQUFXO0FBQ3RCO0FBQ0E7QUFDQSxLQUFLO0FBQ0w7QUFDdUg7O0FBRXZIIiwic291cmNlcyI6WyJ3ZWJwYWNrOi8vb21uaS13ZWIvPzIzZDciXSwic291cmNlc0NvbnRlbnQiOlsiaW1wb3J0IHsgQXBwUm91dGVSb3V0ZU1vZHVsZSB9IGZyb20gXCJuZXh0L2Rpc3Qvc2VydmVyL2Z1dHVyZS9yb3V0ZS1tb2R1bGVzL2FwcC1yb3V0ZS9tb2R1bGUuY29tcGlsZWRcIjtcbmltcG9ydCB7IFJvdXRlS2luZCB9IGZyb20gXCJuZXh0L2Rpc3Qvc2VydmVyL2Z1dHVyZS9yb3V0ZS1raW5kXCI7XG5pbXBvcnQgeyBwYXRjaEZldGNoIGFzIF9wYXRjaEZldGNoIH0gZnJvbSBcIm5leHQvZGlzdC9zZXJ2ZXIvbGliL3BhdGNoLWZldGNoXCI7XG5pbXBvcnQgKiBhcyB1c2VybGFuZCBmcm9tIFwiL1VzZXJzL3hpYW9ib3poYW5nL0RvY3VtZW50cy9HaXRIdWIvb21uaS93ZWIvYXBwL2FwaS90YXJvdC9yb3V0ZS50c1wiO1xuLy8gV2UgaW5qZWN0IHRoZSBuZXh0Q29uZmlnT3V0cHV0IGhlcmUgc28gdGhhdCB3ZSBjYW4gdXNlIHRoZW0gaW4gdGhlIHJvdXRlXG4vLyBtb2R1bGUuXG5jb25zdCBuZXh0Q29uZmlnT3V0cHV0ID0gXCJcIlxuY29uc3Qgcm91dGVNb2R1bGUgPSBuZXcgQXBwUm91dGVSb3V0ZU1vZHVsZSh7XG4gICAgZGVmaW5pdGlvbjoge1xuICAgICAgICBraW5kOiBSb3V0ZUtpbmQuQVBQX1JPVVRFLFxuICAgICAgICBwYWdlOiBcIi9hcGkvdGFyb3Qvcm91dGVcIixcbiAgICAgICAgcGF0aG5hbWU6IFwiL2FwaS90YXJvdFwiLFxuICAgICAgICBmaWxlbmFtZTogXCJyb3V0ZVwiLFxuICAgICAgICBidW5kbGVQYXRoOiBcImFwcC9hcGkvdGFyb3Qvcm91dGVcIlxuICAgIH0sXG4gICAgcmVzb2x2ZWRQYWdlUGF0aDogXCIvVXNlcnMveGlhb2JvemhhbmcvRG9jdW1lbnRzL0dpdEh1Yi9vbW5pL3dlYi9hcHAvYXBpL3Rhcm90L3JvdXRlLnRzXCIsXG4gICAgbmV4dENvbmZpZ091dHB1dCxcbiAgICB1c2VybGFuZFxufSk7XG4vLyBQdWxsIG91dCB0aGUgZXhwb3J0cyB0aGF0IHdlIG5lZWQgdG8gZXhwb3NlIGZyb20gdGhlIG1vZHVsZS4gVGhpcyBzaG91bGRcbi8vIGJlIGVsaW1pbmF0ZWQgd2hlbiB3ZSd2ZSBtb3ZlZCB0aGUgb3RoZXIgcm91dGVzIHRvIHRoZSBuZXcgZm9ybWF0LiBUaGVzZVxuLy8gYXJlIHVzZWQgdG8gaG9vayBpbnRvIHRoZSByb3V0ZS5cbmNvbnN0IHsgcmVxdWVzdEFzeW5jU3RvcmFnZSwgc3RhdGljR2VuZXJhdGlvbkFzeW5jU3RvcmFnZSwgc2VydmVySG9va3MgfSA9IHJvdXRlTW9kdWxlO1xuY29uc3Qgb3JpZ2luYWxQYXRobmFtZSA9IFwiL2FwaS90YXJvdC9yb3V0ZVwiO1xuZnVuY3Rpb24gcGF0Y2hGZXRjaCgpIHtcbiAgICByZXR1cm4gX3BhdGNoRmV0Y2goe1xuICAgICAgICBzZXJ2ZXJIb29rcyxcbiAgICAgICAgc3RhdGljR2VuZXJhdGlvbkFzeW5jU3RvcmFnZVxuICAgIH0pO1xufVxuZXhwb3J0IHsgcm91dGVNb2R1bGUsIHJlcXVlc3RBc3luY1N0b3JhZ2UsIHN0YXRpY0dlbmVyYXRpb25Bc3luY1N0b3JhZ2UsIHNlcnZlckhvb2tzLCBvcmlnaW5hbFBhdGhuYW1lLCBwYXRjaEZldGNoLCAgfTtcblxuLy8jIHNvdXJjZU1hcHBpbmdVUkw9YXBwLXJvdXRlLmpzLm1hcCJdLCJuYW1lcyI6W10sInNvdXJjZVJvb3QiOiIifQ==\n//# sourceURL=webpack-internal:///(rsc)/./node_modules/next/dist/build/webpack/loaders/next-app-loader.js?name=app%2Fapi%2Ftarot%2Froute&page=%2Fapi%2Ftarot%2Froute&appPaths=&pagePath=private-next-app-dir%2Fapi%2Ftarot%2Froute.ts&appDir=%2FUsers%2Fxiaobozhang%2FDocuments%2FGitHub%2Fomni%2Fweb%2Fapp&pageExtensions=tsx&pageExtensions=ts&pageExtensions=jsx&pageExtensions=js&rootDir=%2FUsers%2Fxiaobozhang%2FDocuments%2FGitHub%2Fomni%2Fweb&isDev=true&tsconfigPath=tsconfig.json&basePath=&assetPrefix=&nextConfigOutput=&preferredRegion=&middlewareConfig=e30%3D!\n");

/***/ }),

/***/ "(rsc)/./app/api/tarot/route.ts":
/*!********************************!*\
  !*** ./app/api/tarot/route.ts ***!
  \********************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

eval("__webpack_require__.r(__webpack_exports__);\n/* harmony export */ __webpack_require__.d(__webpack_exports__, {\n/* harmony export */   POST: () => (/* binding */ POST)\n/* harmony export */ });\n/* harmony import */ var next_server__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! next/server */ \"(rsc)/./node_modules/next/dist/api/server.js\");\n\nconst majorArcana = [\n    \"The Fool\",\n    \"The Magician\",\n    \"The High Priestess\",\n    \"The Empress\",\n    \"The Emperor\",\n    \"The Hierophant\",\n    \"The Lovers\",\n    \"The Chariot\",\n    \"Strength\",\n    \"The Hermit\",\n    \"Wheel of Fortune\",\n    \"Justice\",\n    \"The Hanged Man\",\n    \"Death\",\n    \"Temperance\",\n    \"The Devil\",\n    \"The Tower\",\n    \"The Star\",\n    \"The Moon\",\n    \"The Sun\",\n    \"Judgement\",\n    \"The World\"\n];\nconst majorArcanaZh = [\n    \"愚人\",\n    \"魔术师\",\n    \"女祭司\",\n    \"皇后\",\n    \"皇帝\",\n    \"教皇\",\n    \"恋人\",\n    \"战车\",\n    \"力量\",\n    \"隐士\",\n    \"命运之轮\",\n    \"正义\",\n    \"倒吊人\",\n    \"死神\",\n    \"节制\",\n    \"恶魔\",\n    \"高塔\",\n    \"星星\",\n    \"月亮\",\n    \"太阳\",\n    \"审判\",\n    \"世界\"\n];\nconst suits = [\n    \"Wands\",\n    \"Cups\",\n    \"Swords\",\n    \"Pentacles\"\n];\nconst suitsZh = [\n    \"权杖\",\n    \"圣杯\",\n    \"宝剑\",\n    \"星币\"\n];\nconst values = [\n    \"Ace\",\n    \"2\",\n    \"3\",\n    \"4\",\n    \"5\",\n    \"6\",\n    \"7\",\n    \"8\",\n    \"9\",\n    \"10\",\n    \"Page\",\n    \"Knight\",\n    \"Queen\",\n    \"King\"\n];\nconst valuesZh = [\n    \"首牌\",\n    \"2\",\n    \"3\",\n    \"4\",\n    \"5\",\n    \"6\",\n    \"7\",\n    \"8\",\n    \"9\",\n    \"10\",\n    \"侍从\",\n    \"骑士\",\n    \"王后\",\n    \"国王\"\n];\n// Generate full decks\nconst generateDeck = (majors, suitNames, vals)=>[\n        ...majors.map((name)=>({\n                name,\n                type: \"Major\"\n            })),\n        ...suitNames.flatMap((suit)=>vals.map((val)=>({\n                    name: `${suit}${val}`,\n                    type: \"Minor\"\n                })) // Chinese style usually Suit+Value e.g. 权杖5\n        )\n    ];\nconst deckEn = [\n    ...majorArcana.map((name)=>({\n            name,\n            type: \"Major\"\n        })),\n    ...suits.flatMap((suit)=>values.map((val)=>({\n                name: `${val} of ${suit}`,\n                type: \"Minor\"\n            })))\n];\n// For Chinese deck construction\nconst deckZh = [\n    ...majorArcanaZh.map((name)=>({\n            name,\n            type: \"Major\"\n        })),\n    ...suitsZh.flatMap((suit)=>valuesZh.map((val)=>({\n                name: `${suit}${val}`,\n                type: \"Minor\"\n            })))\n];\n// Fisher-Yates Shuffle\nfunction shuffleDeck(deck) {\n    const newDeck = [\n        ...deck\n    ];\n    for(let i = newDeck.length - 1; i > 0; i--){\n        const j = Math.floor(Math.random() * (i + 1));\n        [newDeck[i], newDeck[j]] = [\n            newDeck[j],\n            newDeck[i]\n        ];\n    }\n    return newDeck;\n}\nasync function POST(request) {\n    try {\n        const body = await request.json();\n        const { question, spreadType, locale } = body;\n        const isZh = locale === \"zh\";\n        const fullDeck = isZh ? deckZh : deckEn;\n        const shuffled = shuffleDeck(fullDeck);\n        // Draw based on spread\n        let drawCount = 3;\n        if (spreadType === \"Celtic Cross\") drawCount = 10;\n        else if (spreadType === \"Decision\") drawCount = 2;\n        // Available images (using the ones we identified)\n        const cardImages = [\n            \"/assets/Gemini_Generated_Image_4n1yx94n1yx94n1y.png\",\n            \"/assets/Gemini_Generated_Image_5lv2xh5lv2xh5lv2.png\",\n            \"/assets/Gemini_Generated_Image_ae247sae247sae24.png\",\n            \"/assets/Gemini_Generated_Image_d51vljd51vljd51v.png\"\n        ];\n        const drawnCards = shuffled.slice(0, drawCount).map((card, index)=>({\n                ...card,\n                isReversed: Math.random() > 0.8,\n                image: cardImages[index % cardImages.length] // Cycle through available images\n            }));\n        // Mock AI interpretation\n        const interpretation = isZh ? `您问了: \"${question}\"。\n    \n    牌面预示着强烈的转变。第一张牌 ${drawnCards[0].name} ${drawnCards[0].isReversed ? \"(逆位)\" : \"\"} 表明您当下的基础正在动摇。\n    \n    随着 ${drawnCards[1].name} 的出现，宇宙召唤您去审视内心的动机。\n    \n    如果您能拥抱 ${drawnCards[drawnCards.length - 1].name} 的能量，结果将是非常积极的。` : `You asked: \"${question}\". \n    \n    The cards suggest a powerful transition. ${drawnCards[0].name} ${drawnCards[0].isReversed ? \"(Reversed)\" : \"\"} in the first position indicates that your current foundation is shifting.\n    \n    With ${drawnCards[1].name} appearing, you are being called to examine your inner motivations.\n    \n    The outcome looks promising if you embrace the energy of ${drawnCards[drawnCards.length - 1].name}.`;\n        // Simulate thinking delay\n        await new Promise((resolve)=>setTimeout(resolve, 1500));\n        // --- Database Integration ---\n        try {\n            const { getServerSession } = await Promise.all(/*! import() */[__webpack_require__.e(\"vendor-chunks/next\"), __webpack_require__.e(\"vendor-chunks/next-auth\"), __webpack_require__.e(\"vendor-chunks/@babel\"), __webpack_require__.e(\"vendor-chunks/jose\"), __webpack_require__.e(\"vendor-chunks/openid-client\"), __webpack_require__.e(\"vendor-chunks/oauth\"), __webpack_require__.e(\"vendor-chunks/preact\"), __webpack_require__.e(\"vendor-chunks/yallist\"), __webpack_require__.e(\"vendor-chunks/preact-render-to-string\"), __webpack_require__.e(\"vendor-chunks/cookie\"), __webpack_require__.e(\"vendor-chunks/oidc-token-hash\"), __webpack_require__.e(\"vendor-chunks/@panva\")]).then(__webpack_require__.t.bind(__webpack_require__, /*! next-auth */ \"(rsc)/./node_modules/next-auth/index.js\", 23));\n            const { authOptions } = await Promise.all(/*! import() */[__webpack_require__.e(\"vendor-chunks/next\"), __webpack_require__.e(\"vendor-chunks/next-auth\"), __webpack_require__.e(\"vendor-chunks/@babel\"), __webpack_require__.e(\"vendor-chunks/jose\"), __webpack_require__.e(\"vendor-chunks/openid-client\"), __webpack_require__.e(\"vendor-chunks/oauth\"), __webpack_require__.e(\"vendor-chunks/preact\"), __webpack_require__.e(\"vendor-chunks/yallist\"), __webpack_require__.e(\"vendor-chunks/preact-render-to-string\"), __webpack_require__.e(\"vendor-chunks/cookie\"), __webpack_require__.e(\"vendor-chunks/oidc-token-hash\"), __webpack_require__.e(\"vendor-chunks/@panva\"), __webpack_require__.e(\"vendor-chunks/@auth\"), __webpack_require__.e(\"_rsc_app_api_auth_nextauth_route_ts\")]).then(__webpack_require__.bind(__webpack_require__, /*! ../auth/[...nextauth]/route */ \"(rsc)/./app/api/auth/[...nextauth]/route.ts\"));\n            const session = await getServerSession(authOptions);\n            if (session?.user?.id) {\n                const { prisma } = await __webpack_require__.e(/*! import() */ \"_rsc_lib_prisma_ts\").then(__webpack_require__.bind(__webpack_require__, /*! @/lib/prisma */ \"(rsc)/./lib/prisma.ts\")); // Dynamic import to avoid circular dep issues if any\n                await prisma.reading.create({\n                    data: {\n                        type: \"TAROT\",\n                        data: {\n                            cards: drawnCards,\n                            spreadType,\n                            question\n                        },\n                        result: interpretation,\n                        userId: session.user.id\n                    }\n                });\n            }\n        } catch (dbError) {\n            console.error(\"Failed to save reading to DB:\", dbError);\n        // We don't fail the request if DB fails, just log it\n        }\n        // ---------------------------\n        return next_server__WEBPACK_IMPORTED_MODULE_0__.NextResponse.json({\n            cards: drawnCards,\n            interpretation\n        });\n    } catch (error) {\n        return next_server__WEBPACK_IMPORTED_MODULE_0__.NextResponse.json({\n            error: \"Invalid request\"\n        }, {\n            status: 400\n        });\n    }\n}\n//# sourceURL=[module]\n//# sourceMappingURL=data:application/json;charset=utf-8;base64,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QUMxQixNQUFNLElBQUltQyxRQUFRQyxDQUFBQSxVQUFXQyxXQUFXRCxTQUFTO1FBRWpELCtCQUErQjtRQUMvQixJQUFJO1lBQ0YsTUFBTSxFQUFFRSxnQkFBZ0IsRUFBRSxHQUFHLE1BQU0sc3VCQUFtQjtZQUN0RCxNQUFNLEVBQUVDLFdBQVcsRUFBRSxHQUFHLE1BQU0sazJCQUFxQztZQUNuRSxNQUFNQyxVQUFVLE1BQU1GLGlCQUFpQkM7WUFFdkMsSUFBSUMsU0FBU0MsTUFBTUMsSUFBSTtnQkFDckIsTUFBTSxFQUFFQyxNQUFNLEVBQUUsR0FBRyxNQUFNLDRKQUFzQixFQUFFLHFEQUFxRDtnQkFDdEcsTUFBTUEsT0FBT0MsT0FBTyxDQUFDQyxNQUFNLENBQUM7b0JBQzFCQyxNQUFNO3dCQUNKN0MsTUFBTTt3QkFDTjZDLE1BQU07NEJBQUVDLE9BQU9uQjs0QkFBWVA7NEJBQVlEO3dCQUFTO3dCQUNoRDRCLFFBQVFkO3dCQUNSZSxRQUFRVCxRQUFRQyxJQUFJLENBQUNDLEVBQUU7b0JBQ3pCO2dCQUNGO1lBQ0Y7UUFDRixFQUFFLE9BQU9RLFNBQVM7WUFDaEJDLFFBQVFDLEtBQUssQ0FBQyxpQ0FBaUNGO1FBQy9DLHFEQUFxRDtRQUN2RDtRQUNBLDhCQUE4QjtRQUU5QixPQUFPOUQscURBQVlBLENBQUMrQixJQUFJLENBQUM7WUFDdkI0QixPQUFPbkI7WUFDUE07UUFDRjtJQUVGLEVBQUUsT0FBT2tCLE9BQU87UUFDZCxPQUFPaEUscURBQVlBLENBQUMrQixJQUFJLENBQUM7WUFBRWlDLE9BQU87UUFBa0IsR0FBRztZQUFFQyxRQUFRO1FBQUk7SUFDdkU7QUFDRiIsInNvdXJjZXMiOlsid2VicGFjazovL29tbmktd2ViLy4vYXBwL2FwaS90YXJvdC9yb3V0ZS50cz8xYjNkIl0sInNvdXJjZXNDb250ZW50IjpbImltcG9ydCB7IE5leHRSZXNwb25zZSB9IGZyb20gJ25leHQvc2VydmVyJztcblxuY29uc3QgbWFqb3JBcmNhbmEgPSBbXG4gIFwiVGhlIEZvb2xcIiwgXCJUaGUgTWFnaWNpYW5cIiwgXCJUaGUgSGlnaCBQcmllc3Rlc3NcIiwgXCJUaGUgRW1wcmVzc1wiLCBcIlRoZSBFbXBlcm9yXCIsXG4gIFwiVGhlIEhpZXJvcGhhbnRcIiwgXCJUaGUgTG92ZXJzXCIsIFwiVGhlIENoYXJpb3RcIiwgXCJTdHJlbmd0aFwiLCBcIlRoZSBIZXJtaXRcIixcbiAgXCJXaGVlbCBvZiBGb3J0dW5lXCIsIFwiSnVzdGljZVwiLCBcIlRoZSBIYW5nZWQgTWFuXCIsIFwiRGVhdGhcIiwgXCJUZW1wZXJhbmNlXCIsXG4gIFwiVGhlIERldmlsXCIsIFwiVGhlIFRvd2VyXCIsIFwiVGhlIFN0YXJcIiwgXCJUaGUgTW9vblwiLCBcIlRoZSBTdW5cIixcbiAgXCJKdWRnZW1lbnRcIiwgXCJUaGUgV29ybGRcIlxuXTtcblxuY29uc3QgbWFqb3JBcmNhbmFaaCA9IFtcbiAgXCLmhJrkurpcIiwgXCLprZTmnK/luIhcIiwgXCLlpbPnpa3lj7hcIiwgXCLnmoflkI5cIiwgXCLnmofluJ1cIixcbiAgXCLmlZnnmodcIiwgXCLmgYvkurpcIiwgXCLmiJjovaZcIiwgXCLlipvph49cIiwgXCLpmpDlo6tcIixcbiAgXCLlkb3ov5DkuYvova5cIiwgXCLmraPkuYlcIiwgXCLlgJLlkIrkurpcIiwgXCLmrbvnpZ5cIiwgXCLoioLliLZcIixcbiAgXCLmgbbprZRcIiwgXCLpq5jloZRcIiwgXCLmmJ/mmJ9cIiwgXCLmnIjkuq5cIiwgXCLlpKrpmLNcIixcbiAgXCLlrqHliKRcIiwgXCLkuJbnlYxcIlxuXTtcblxuY29uc3Qgc3VpdHMgPSBbXCJXYW5kc1wiLCBcIkN1cHNcIiwgXCJTd29yZHNcIiwgXCJQZW50YWNsZXNcIl07XG5jb25zdCBzdWl0c1poID0gW1wi5p2D5p2WXCIsIFwi5Zyj5p2vXCIsIFwi5a6d5YmRXCIsIFwi5pif5biBXCJdO1xuXG5jb25zdCB2YWx1ZXMgPSBbXCJBY2VcIiwgXCIyXCIsIFwiM1wiLCBcIjRcIiwgXCI1XCIsIFwiNlwiLCBcIjdcIiwgXCI4XCIsIFwiOVwiLCBcIjEwXCIsIFwiUGFnZVwiLCBcIktuaWdodFwiLCBcIlF1ZWVuXCIsIFwiS2luZ1wiXTtcbmNvbnN0IHZhbHVlc1poID0gW1wi6aaW54mMXCIsIFwiMlwiLCBcIjNcIiwgXCI0XCIsIFwiNVwiLCBcIjZcIiwgXCI3XCIsIFwiOFwiLCBcIjlcIiwgXCIxMFwiLCBcIuS+jeS7jlwiLCBcIumqkeWjq1wiLCBcIueOi+WQjlwiLCBcIuWbveeOi1wiXTtcblxuLy8gR2VuZXJhdGUgZnVsbCBkZWNrc1xuY29uc3QgZ2VuZXJhdGVEZWNrID0gKG1ham9yczogc3RyaW5nW10sIHN1aXROYW1lczogc3RyaW5nW10sIHZhbHM6IHN0cmluZ1tdKSA9PiBbXG4gIC4uLm1ham9ycy5tYXAobmFtZSA9PiAoeyBuYW1lLCB0eXBlOiAnTWFqb3InIH0pKSxcbiAgLi4uc3VpdE5hbWVzLmZsYXRNYXAoc3VpdCA9PlxuICAgIHZhbHMubWFwKHZhbCA9PiAoeyBuYW1lOiBgJHtzdWl0fSR7dmFsfWAsIHR5cGU6ICdNaW5vcicgfSkpIC8vIENoaW5lc2Ugc3R5bGUgdXN1YWxseSBTdWl0K1ZhbHVlIGUuZy4g5p2D5p2WNVxuICApXG5dO1xuXG5jb25zdCBkZWNrRW4gPSBbXG4gIC4uLm1ham9yQXJjYW5hLm1hcChuYW1lID0+ICh7IG5hbWUsIHR5cGU6ICdNYWpvcicgfSkpLFxuICAuLi5zdWl0cy5mbGF0TWFwKHN1aXQgPT5cbiAgICB2YWx1ZXMubWFwKHZhbCA9PiAoeyBuYW1lOiBgJHt2YWx9IG9mICR7c3VpdH1gLCB0eXBlOiAnTWlub3InIH0pKVxuICApXG5dO1xuXG4vLyBGb3IgQ2hpbmVzZSBkZWNrIGNvbnN0cnVjdGlvblxuY29uc3QgZGVja1poID0gW1xuICAuLi5tYWpvckFyY2FuYVpoLm1hcChuYW1lID0+ICh7IG5hbWUsIHR5cGU6ICdNYWpvcicgfSkpLFxuICAuLi5zdWl0c1poLmZsYXRNYXAoc3VpdCA9PlxuICAgIHZhbHVlc1poLm1hcCh2YWwgPT4gKHsgbmFtZTogYCR7c3VpdH0ke3ZhbH1gLCB0eXBlOiAnTWlub3InIH0pKVxuICApXG5dO1xuXG5cbi8vIEZpc2hlci1ZYXRlcyBTaHVmZmxlXG5mdW5jdGlvbiBzaHVmZmxlRGVjayhkZWNrOiBhbnlbXSkge1xuICBjb25zdCBuZXdEZWNrID0gWy4uLmRlY2tdO1xuICBmb3IgKGxldCBpID0gbmV3RGVjay5sZW5ndGggLSAxOyBpID4gMDsgaS0tKSB7XG4gICAgY29uc3QgaiA9IE1hdGguZmxvb3IoTWF0aC5yYW5kb20oKSAqIChpICsgMSkpO1xuICAgIFtuZXdEZWNrW2ldLCBuZXdEZWNrW2pdXSA9IFtuZXdEZWNrW2pdLCBuZXdEZWNrW2ldXTtcbiAgfVxuICByZXR1cm4gbmV3RGVjaztcbn1cblxuZXhwb3J0IGFzeW5jIGZ1bmN0aW9uIFBPU1QocmVxdWVzdDogUmVxdWVzdCkge1xuICB0cnkge1xuICAgIGNvbnN0IGJvZHkgPSBhd2FpdCByZXF1ZXN0Lmpzb24oKTtcbiAgICBjb25zdCB7IHF1ZXN0aW9uLCBzcHJlYWRUeXBlLCBsb2NhbGUgfSA9IGJvZHk7XG4gICAgY29uc3QgaXNaaCA9IGxvY2FsZSA9PT0gJ3poJztcblxuICAgIGNvbnN0IGZ1bGxEZWNrID0gaXNaaCA/IGRlY2taaCA6IGRlY2tFbjtcbiAgICBjb25zdCBzaHVmZmxlZCA9IHNodWZmbGVEZWNrKGZ1bGxEZWNrKTtcblxuICAgIC8vIERyYXcgYmFzZWQgb24gc3ByZWFkXG4gICAgbGV0IGRyYXdDb3VudCA9IDM7XG4gICAgaWYgKHNwcmVhZFR5cGUgPT09ICdDZWx0aWMgQ3Jvc3MnKSBkcmF3Q291bnQgPSAxMDtcbiAgICBlbHNlIGlmIChzcHJlYWRUeXBlID09PSAnRGVjaXNpb24nKSBkcmF3Q291bnQgPSAyO1xuXG4gICAgLy8gQXZhaWxhYmxlIGltYWdlcyAodXNpbmcgdGhlIG9uZXMgd2UgaWRlbnRpZmllZClcbiAgICBjb25zdCBjYXJkSW1hZ2VzID0gW1xuICAgICAgXCIvYXNzZXRzL0dlbWluaV9HZW5lcmF0ZWRfSW1hZ2VfNG4xeXg5NG4xeXg5NG4xeS5wbmdcIixcbiAgICAgIFwiL2Fzc2V0cy9HZW1pbmlfR2VuZXJhdGVkX0ltYWdlXzVsdjJ4aDVsdjJ4aDVsdjIucG5nXCIsXG4gICAgICBcIi9hc3NldHMvR2VtaW5pX0dlbmVyYXRlZF9JbWFnZV9hZTI0N3NhZTI0N3NhZTI0LnBuZ1wiLFxuICAgICAgXCIvYXNzZXRzL0dlbWluaV9HZW5lcmF0ZWRfSW1hZ2VfZDUxdmxqZDUxdmxqZDUxdi5wbmdcIlxuICAgIF07XG5cbiAgICBjb25zdCBkcmF3bkNhcmRzID0gc2h1ZmZsZWQuc2xpY2UoMCwgZHJhd0NvdW50KS5tYXAoKGNhcmQsIGluZGV4KSA9PiAoe1xuICAgICAgLi4uY2FyZCxcbiAgICAgIGlzUmV2ZXJzZWQ6IE1hdGgucmFuZG9tKCkgPiAwLjgsIC8vIDIwJSBjaGFuY2Ugb2YgcmV2ZXJzYWxcbiAgICAgIGltYWdlOiBjYXJkSW1hZ2VzW2luZGV4ICUgY2FyZEltYWdlcy5sZW5ndGhdIC8vIEN5Y2xlIHRocm91Z2ggYXZhaWxhYmxlIGltYWdlc1xuICAgIH0pKTtcblxuICAgIC8vIE1vY2sgQUkgaW50ZXJwcmV0YXRpb25cbiAgICBjb25zdCBpbnRlcnByZXRhdGlvbiA9IGlzWmhcbiAgICAgID8gYOaCqOmXruS6hjogXCIke3F1ZXN0aW9ufVwi44CCXG4gICAgXG4gICAg54mM6Z2i6aKE56S6552A5by654OI55qE6L2s5Y+Y44CC56ys5LiA5byg54mMICR7ZHJhd25DYXJkc1swXS5uYW1lfSAke2RyYXduQ2FyZHNbMF0uaXNSZXZlcnNlZCA/ICco6YCG5L2NKScgOiAnJ30g6KGo5piO5oKo5b2T5LiL55qE5Z+656GA5q2j5Zyo5Yqo5pGH44CCXG4gICAgXG4gICAg6ZqP552AICR7ZHJhd25DYXJkc1sxXS5uYW1lfSDnmoTlh7rnjrDvvIzlroflrpnlj6zllKTmgqjljrvlrqHop4blhoXlv4PnmoTliqjmnLrjgIJcbiAgICBcbiAgICDlpoLmnpzmgqjog73mi6XmirEgJHtkcmF3bkNhcmRzW2RyYXduQ2FyZHMubGVuZ3RoIC0gMV0ubmFtZX0g55qE6IO96YeP77yM57uT5p6c5bCG5piv6Z2e5bi456ev5p6B55qE44CCYFxuICAgICAgOiBgWW91IGFza2VkOiBcIiR7cXVlc3Rpb259XCIuIFxuICAgIFxuICAgIFRoZSBjYXJkcyBzdWdnZXN0IGEgcG93ZXJmdWwgdHJhbnNpdGlvbi4gJHtkcmF3bkNhcmRzWzBdLm5hbWV9ICR7ZHJhd25DYXJkc1swXS5pc1JldmVyc2VkID8gJyhSZXZlcnNlZCknIDogJyd9IGluIHRoZSBmaXJzdCBwb3NpdGlvbiBpbmRpY2F0ZXMgdGhhdCB5b3VyIGN1cnJlbnQgZm91bmRhdGlvbiBpcyBzaGlmdGluZy5cbiAgICBcbiAgICBXaXRoICR7ZHJhd25DYXJkc1sxXS5uYW1lfSBhcHBlYXJpbmcsIHlvdSBhcmUgYmVpbmcgY2FsbGVkIHRvIGV4YW1pbmUgeW91ciBpbm5lciBtb3RpdmF0aW9ucy5cbiAgICBcbiAgICBUaGUgb3V0Y29tZSBsb29rcyBwcm9taXNpbmcgaWYgeW91IGVtYnJhY2UgdGhlIGVuZXJneSBvZiAke2RyYXduQ2FyZHNbZHJhd25DYXJkcy5sZW5ndGggLSAxXS5uYW1lfS5gO1xuXG4gICAgLy8gU2ltdWxhdGUgdGhpbmtpbmcgZGVsYXlcbiAgICBhd2FpdCBuZXcgUHJvbWlzZShyZXNvbHZlID0+IHNldFRpbWVvdXQocmVzb2x2ZSwgMTUwMCkpO1xuXG4gICAgLy8gLS0tIERhdGFiYXNlIEludGVncmF0aW9uIC0tLVxuICAgIHRyeSB7XG4gICAgICBjb25zdCB7IGdldFNlcnZlclNlc3Npb24gfSA9IGF3YWl0IGltcG9ydChcIm5leHQtYXV0aFwiKTtcbiAgICAgIGNvbnN0IHsgYXV0aE9wdGlvbnMgfSA9IGF3YWl0IGltcG9ydChcIi4uL2F1dGgvWy4uLm5leHRhdXRoXS9yb3V0ZVwiKTtcbiAgICAgIGNvbnN0IHNlc3Npb24gPSBhd2FpdCBnZXRTZXJ2ZXJTZXNzaW9uKGF1dGhPcHRpb25zKTtcblxuICAgICAgaWYgKHNlc3Npb24/LnVzZXI/LmlkKSB7XG4gICAgICAgIGNvbnN0IHsgcHJpc21hIH0gPSBhd2FpdCBpbXBvcnQoXCJAL2xpYi9wcmlzbWFcIik7IC8vIER5bmFtaWMgaW1wb3J0IHRvIGF2b2lkIGNpcmN1bGFyIGRlcCBpc3N1ZXMgaWYgYW55XG4gICAgICAgIGF3YWl0IHByaXNtYS5yZWFkaW5nLmNyZWF0ZSh7XG4gICAgICAgICAgZGF0YToge1xuICAgICAgICAgICAgdHlwZTogXCJUQVJPVFwiLFxuICAgICAgICAgICAgZGF0YTogeyBjYXJkczogZHJhd25DYXJkcywgc3ByZWFkVHlwZSwgcXVlc3Rpb24gfSxcbiAgICAgICAgICAgIHJlc3VsdDogaW50ZXJwcmV0YXRpb24sXG4gICAgICAgICAgICB1c2VySWQ6IHNlc3Npb24udXNlci5pZFxuICAgICAgICAgIH1cbiAgICAgICAgfSk7XG4gICAgICB9XG4gICAgfSBjYXRjaCAoZGJFcnJvcikge1xuICAgICAgY29uc29sZS5lcnJvcihcIkZhaWxlZCB0byBzYXZlIHJlYWRpbmcgdG8gREI6XCIsIGRiRXJyb3IpO1xuICAgICAgLy8gV2UgZG9uJ3QgZmFpbCB0aGUgcmVxdWVzdCBpZiBEQiBmYWlscywganVzdCBsb2cgaXRcbiAgICB9XG4gICAgLy8gLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tXG5cbiAgICByZXR1cm4gTmV4dFJlc3BvbnNlLmpzb24oe1xuICAgICAgY2FyZHM6IGRyYXduQ2FyZHMsXG4gICAgICBpbnRlcnByZXRhdGlvblxuICAgIH0pO1xuXG4gIH0gY2F0Y2ggKGVycm9yKSB7XG4gICAgcmV0dXJuIE5leHRSZXNwb25zZS5qc29uKHsgZXJyb3I6IFwiSW52YWxpZCByZXF1ZXN0XCIgfSwgeyBzdGF0dXM6IDQwMCB9KTtcbiAgfVxufVxuIl0sIm5hbWVzIjpbIk5leHRSZXNwb25zZSIsIm1ham9yQXJjYW5hIiwibWFqb3JBcmNhbmFaaCIsInN1aXRzIiwic3VpdHNaaCIsInZhbHVlcyIsInZhbHVlc1poIiwiZ2VuZXJhdGVEZWNrIiwibWFqb3JzIiwic3VpdE5hbWVzIiwidmFscyIsIm1hcCIsIm5hbWUiLCJ0eXBlIiwiZmxhdE1hcCIsInN1aXQiLCJ2YWwiLCJkZWNrRW4iLCJkZWNrWmgiLCJzaHVmZmxlRGVjayIsImRlY2siLCJuZXdEZWNrIiwiaSIsImxlbmd0aCIsImoiLCJNYXRoIiwiZmxvb3IiLCJyYW5kb20iLCJQT1NUIiwicmVxdWVzdCIsImJvZHkiLCJqc29uIiwicXVlc3Rpb24iLCJzcHJlYWRUeXBlIiwibG9jYWxlIiwiaXNaaCIsImZ1bGxEZWNrIiwic2h1ZmZsZWQiLCJkcmF3Q291bnQiLCJjYXJkSW1hZ2VzIiwiZHJhd25DYXJkcyIsInNsaWNlIiwiY2FyZCIsImluZGV4IiwiaXNSZXZlcnNlZCIsImltYWdlIiwiaW50ZXJwcmV0YXRpb24iLCJQcm9taXNlIiwicmVzb2x2ZSIsInNldFRpbWVvdXQiLCJnZXRTZXJ2ZXJTZXNzaW9uIiwiYXV0aE9wdGlvbnMiLCJzZXNzaW9uIiwidXNlciIsImlkIiwicHJpc21hIiwicmVhZGluZyIsImNyZWF0ZSIsImRhdGEiLCJjYXJkcyIsInJlc3VsdCIsInVzZXJJZCIsImRiRXJyb3IiLCJjb25zb2xlIiwiZXJyb3IiLCJzdGF0dXMiXSwic291cmNlUm9vdCI6IiJ9\n//# sourceURL=webpack-internal:///(rsc)/./app/api/tarot/route.ts\n");

/***/ })

};
;

// load runtime
var __webpack_require__ = require("../../../webpack-runtime.js");
__webpack_require__.C(exports);
var __webpack_exec__ = (moduleId) => (__webpack_require__(__webpack_require__.s = moduleId))
var __webpack_exports__ = __webpack_require__.X(0, ["vendor-chunks/next"], () => (__webpack_exec__("(rsc)/./node_modules/next/dist/build/webpack/loaders/next-app-loader.js?name=app%2Fapi%2Ftarot%2Froute&page=%2Fapi%2Ftarot%2Froute&appPaths=&pagePath=private-next-app-dir%2Fapi%2Ftarot%2Froute.ts&appDir=%2FUsers%2Fxiaobozhang%2FDocuments%2FGitHub%2Fomni%2Fweb%2Fapp&pageExtensions=tsx&pageExtensions=ts&pageExtensions=jsx&pageExtensions=js&rootDir=%2FUsers%2Fxiaobozhang%2FDocuments%2FGitHub%2Fomni%2Fweb&isDev=true&tsconfigPath=tsconfig.json&basePath=&assetPrefix=&nextConfigOutput=&preferredRegion=&middlewareConfig=e30%3D!")));
module.exports = __webpack_exports__;

})();