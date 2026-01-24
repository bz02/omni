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
exports.id = "app/api/mbti/route";
exports.ids = ["app/api/mbti/route"];
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

/***/ "(rsc)/./node_modules/next/dist/build/webpack/loaders/next-app-loader.js?name=app%2Fapi%2Fmbti%2Froute&page=%2Fapi%2Fmbti%2Froute&appPaths=&pagePath=private-next-app-dir%2Fapi%2Fmbti%2Froute.ts&appDir=%2FUsers%2Fxiaobozhang%2FDocuments%2FGitHub%2Fomni%2Fweb%2Fapp&pageExtensions=tsx&pageExtensions=ts&pageExtensions=jsx&pageExtensions=js&rootDir=%2FUsers%2Fxiaobozhang%2FDocuments%2FGitHub%2Fomni%2Fweb&isDev=true&tsconfigPath=tsconfig.json&basePath=&assetPrefix=&nextConfigOutput=&preferredRegion=&middlewareConfig=e30%3D!":
/*!********************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************!*\
  !*** ./node_modules/next/dist/build/webpack/loaders/next-app-loader.js?name=app%2Fapi%2Fmbti%2Froute&page=%2Fapi%2Fmbti%2Froute&appPaths=&pagePath=private-next-app-dir%2Fapi%2Fmbti%2Froute.ts&appDir=%2FUsers%2Fxiaobozhang%2FDocuments%2FGitHub%2Fomni%2Fweb%2Fapp&pageExtensions=tsx&pageExtensions=ts&pageExtensions=jsx&pageExtensions=js&rootDir=%2FUsers%2Fxiaobozhang%2FDocuments%2FGitHub%2Fomni%2Fweb&isDev=true&tsconfigPath=tsconfig.json&basePath=&assetPrefix=&nextConfigOutput=&preferredRegion=&middlewareConfig=e30%3D! ***!
  \********************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

eval("__webpack_require__.r(__webpack_exports__);\n/* harmony export */ __webpack_require__.d(__webpack_exports__, {\n/* harmony export */   originalPathname: () => (/* binding */ originalPathname),\n/* harmony export */   patchFetch: () => (/* binding */ patchFetch),\n/* harmony export */   requestAsyncStorage: () => (/* binding */ requestAsyncStorage),\n/* harmony export */   routeModule: () => (/* binding */ routeModule),\n/* harmony export */   serverHooks: () => (/* binding */ serverHooks),\n/* harmony export */   staticGenerationAsyncStorage: () => (/* binding */ staticGenerationAsyncStorage)\n/* harmony export */ });\n/* harmony import */ var next_dist_server_future_route_modules_app_route_module_compiled__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! next/dist/server/future/route-modules/app-route/module.compiled */ \"(rsc)/./node_modules/next/dist/server/future/route-modules/app-route/module.compiled.js\");\n/* harmony import */ var next_dist_server_future_route_modules_app_route_module_compiled__WEBPACK_IMPORTED_MODULE_0___default = /*#__PURE__*/__webpack_require__.n(next_dist_server_future_route_modules_app_route_module_compiled__WEBPACK_IMPORTED_MODULE_0__);\n/* harmony import */ var next_dist_server_future_route_kind__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! next/dist/server/future/route-kind */ \"(rsc)/./node_modules/next/dist/server/future/route-kind.js\");\n/* harmony import */ var next_dist_server_lib_patch_fetch__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! next/dist/server/lib/patch-fetch */ \"(rsc)/./node_modules/next/dist/server/lib/patch-fetch.js\");\n/* harmony import */ var next_dist_server_lib_patch_fetch__WEBPACK_IMPORTED_MODULE_2___default = /*#__PURE__*/__webpack_require__.n(next_dist_server_lib_patch_fetch__WEBPACK_IMPORTED_MODULE_2__);\n/* harmony import */ var _Users_xiaobozhang_Documents_GitHub_omni_web_app_api_mbti_route_ts__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! ./app/api/mbti/route.ts */ \"(rsc)/./app/api/mbti/route.ts\");\n\n\n\n\n// We inject the nextConfigOutput here so that we can use them in the route\n// module.\nconst nextConfigOutput = \"\"\nconst routeModule = new next_dist_server_future_route_modules_app_route_module_compiled__WEBPACK_IMPORTED_MODULE_0__.AppRouteRouteModule({\n    definition: {\n        kind: next_dist_server_future_route_kind__WEBPACK_IMPORTED_MODULE_1__.RouteKind.APP_ROUTE,\n        page: \"/api/mbti/route\",\n        pathname: \"/api/mbti\",\n        filename: \"route\",\n        bundlePath: \"app/api/mbti/route\"\n    },\n    resolvedPagePath: \"/Users/xiaobozhang/Documents/GitHub/omni/web/app/api/mbti/route.ts\",\n    nextConfigOutput,\n    userland: _Users_xiaobozhang_Documents_GitHub_omni_web_app_api_mbti_route_ts__WEBPACK_IMPORTED_MODULE_3__\n});\n// Pull out the exports that we need to expose from the module. This should\n// be eliminated when we've moved the other routes to the new format. These\n// are used to hook into the route.\nconst { requestAsyncStorage, staticGenerationAsyncStorage, serverHooks } = routeModule;\nconst originalPathname = \"/api/mbti/route\";\nfunction patchFetch() {\n    return (0,next_dist_server_lib_patch_fetch__WEBPACK_IMPORTED_MODULE_2__.patchFetch)({\n        serverHooks,\n        staticGenerationAsyncStorage\n    });\n}\n\n\n//# sourceMappingURL=app-route.js.map//# sourceURL=[module]\n//# sourceMappingURL=data:application/json;charset=utf-8;base64,eyJ2ZXJzaW9uIjozLCJmaWxlIjoiKHJzYykvLi9ub2RlX21vZHVsZXMvbmV4dC9kaXN0L2J1aWxkL3dlYnBhY2svbG9hZGVycy9uZXh0LWFwcC1sb2FkZXIuanM/bmFtZT1hcHAlMkZhcGklMkZtYnRpJTJGcm91dGUmcGFnZT0lMkZhcGklMkZtYnRpJTJGcm91dGUmYXBwUGF0aHM9JnBhZ2VQYXRoPXByaXZhdGUtbmV4dC1hcHAtZGlyJTJGYXBpJTJGbWJ0aSUyRnJvdXRlLnRzJmFwcERpcj0lMkZVc2VycyUyRnhpYW9ib3poYW5nJTJGRG9jdW1lbnRzJTJGR2l0SHViJTJGb21uaSUyRndlYiUyRmFwcCZwYWdlRXh0ZW5zaW9ucz10c3gmcGFnZUV4dGVuc2lvbnM9dHMmcGFnZUV4dGVuc2lvbnM9anN4JnBhZ2VFeHRlbnNpb25zPWpzJnJvb3REaXI9JTJGVXNlcnMlMkZ4aWFvYm96aGFuZyUyRkRvY3VtZW50cyUyRkdpdEh1YiUyRm9tbmklMkZ3ZWImaXNEZXY9dHJ1ZSZ0c2NvbmZpZ1BhdGg9dHNjb25maWcuanNvbiZiYXNlUGF0aD0mYXNzZXRQcmVmaXg9Jm5leHRDb25maWdPdXRwdXQ9JnByZWZlcnJlZFJlZ2lvbj0mbWlkZGxld2FyZUNvbmZpZz1lMzAlM0QhIiwibWFwcGluZ3MiOiI7Ozs7Ozs7Ozs7Ozs7OztBQUFzRztBQUN2QztBQUNjO0FBQ2tCO0FBQy9GO0FBQ0E7QUFDQTtBQUNBLHdCQUF3QixnSEFBbUI7QUFDM0M7QUFDQSxjQUFjLHlFQUFTO0FBQ3ZCO0FBQ0E7QUFDQTtBQUNBO0FBQ0EsS0FBSztBQUNMO0FBQ0E7QUFDQSxZQUFZO0FBQ1osQ0FBQztBQUNEO0FBQ0E7QUFDQTtBQUNBLFFBQVEsaUVBQWlFO0FBQ3pFO0FBQ0E7QUFDQSxXQUFXLDRFQUFXO0FBQ3RCO0FBQ0E7QUFDQSxLQUFLO0FBQ0w7QUFDdUg7O0FBRXZIIiwic291cmNlcyI6WyJ3ZWJwYWNrOi8vb21uaS13ZWIvPzU5MDQiXSwic291cmNlc0NvbnRlbnQiOlsiaW1wb3J0IHsgQXBwUm91dGVSb3V0ZU1vZHVsZSB9IGZyb20gXCJuZXh0L2Rpc3Qvc2VydmVyL2Z1dHVyZS9yb3V0ZS1tb2R1bGVzL2FwcC1yb3V0ZS9tb2R1bGUuY29tcGlsZWRcIjtcbmltcG9ydCB7IFJvdXRlS2luZCB9IGZyb20gXCJuZXh0L2Rpc3Qvc2VydmVyL2Z1dHVyZS9yb3V0ZS1raW5kXCI7XG5pbXBvcnQgeyBwYXRjaEZldGNoIGFzIF9wYXRjaEZldGNoIH0gZnJvbSBcIm5leHQvZGlzdC9zZXJ2ZXIvbGliL3BhdGNoLWZldGNoXCI7XG5pbXBvcnQgKiBhcyB1c2VybGFuZCBmcm9tIFwiL1VzZXJzL3hpYW9ib3poYW5nL0RvY3VtZW50cy9HaXRIdWIvb21uaS93ZWIvYXBwL2FwaS9tYnRpL3JvdXRlLnRzXCI7XG4vLyBXZSBpbmplY3QgdGhlIG5leHRDb25maWdPdXRwdXQgaGVyZSBzbyB0aGF0IHdlIGNhbiB1c2UgdGhlbSBpbiB0aGUgcm91dGVcbi8vIG1vZHVsZS5cbmNvbnN0IG5leHRDb25maWdPdXRwdXQgPSBcIlwiXG5jb25zdCByb3V0ZU1vZHVsZSA9IG5ldyBBcHBSb3V0ZVJvdXRlTW9kdWxlKHtcbiAgICBkZWZpbml0aW9uOiB7XG4gICAgICAgIGtpbmQ6IFJvdXRlS2luZC5BUFBfUk9VVEUsXG4gICAgICAgIHBhZ2U6IFwiL2FwaS9tYnRpL3JvdXRlXCIsXG4gICAgICAgIHBhdGhuYW1lOiBcIi9hcGkvbWJ0aVwiLFxuICAgICAgICBmaWxlbmFtZTogXCJyb3V0ZVwiLFxuICAgICAgICBidW5kbGVQYXRoOiBcImFwcC9hcGkvbWJ0aS9yb3V0ZVwiXG4gICAgfSxcbiAgICByZXNvbHZlZFBhZ2VQYXRoOiBcIi9Vc2Vycy94aWFvYm96aGFuZy9Eb2N1bWVudHMvR2l0SHViL29tbmkvd2ViL2FwcC9hcGkvbWJ0aS9yb3V0ZS50c1wiLFxuICAgIG5leHRDb25maWdPdXRwdXQsXG4gICAgdXNlcmxhbmRcbn0pO1xuLy8gUHVsbCBvdXQgdGhlIGV4cG9ydHMgdGhhdCB3ZSBuZWVkIHRvIGV4cG9zZSBmcm9tIHRoZSBtb2R1bGUuIFRoaXMgc2hvdWxkXG4vLyBiZSBlbGltaW5hdGVkIHdoZW4gd2UndmUgbW92ZWQgdGhlIG90aGVyIHJvdXRlcyB0byB0aGUgbmV3IGZvcm1hdC4gVGhlc2Vcbi8vIGFyZSB1c2VkIHRvIGhvb2sgaW50byB0aGUgcm91dGUuXG5jb25zdCB7IHJlcXVlc3RBc3luY1N0b3JhZ2UsIHN0YXRpY0dlbmVyYXRpb25Bc3luY1N0b3JhZ2UsIHNlcnZlckhvb2tzIH0gPSByb3V0ZU1vZHVsZTtcbmNvbnN0IG9yaWdpbmFsUGF0aG5hbWUgPSBcIi9hcGkvbWJ0aS9yb3V0ZVwiO1xuZnVuY3Rpb24gcGF0Y2hGZXRjaCgpIHtcbiAgICByZXR1cm4gX3BhdGNoRmV0Y2goe1xuICAgICAgICBzZXJ2ZXJIb29rcyxcbiAgICAgICAgc3RhdGljR2VuZXJhdGlvbkFzeW5jU3RvcmFnZVxuICAgIH0pO1xufVxuZXhwb3J0IHsgcm91dGVNb2R1bGUsIHJlcXVlc3RBc3luY1N0b3JhZ2UsIHN0YXRpY0dlbmVyYXRpb25Bc3luY1N0b3JhZ2UsIHNlcnZlckhvb2tzLCBvcmlnaW5hbFBhdGhuYW1lLCBwYXRjaEZldGNoLCAgfTtcblxuLy8jIHNvdXJjZU1hcHBpbmdVUkw9YXBwLXJvdXRlLmpzLm1hcCJdLCJuYW1lcyI6W10sInNvdXJjZVJvb3QiOiIifQ==\n//# sourceURL=webpack-internal:///(rsc)/./node_modules/next/dist/build/webpack/loaders/next-app-loader.js?name=app%2Fapi%2Fmbti%2Froute&page=%2Fapi%2Fmbti%2Froute&appPaths=&pagePath=private-next-app-dir%2Fapi%2Fmbti%2Froute.ts&appDir=%2FUsers%2Fxiaobozhang%2FDocuments%2FGitHub%2Fomni%2Fweb%2Fapp&pageExtensions=tsx&pageExtensions=ts&pageExtensions=jsx&pageExtensions=js&rootDir=%2FUsers%2Fxiaobozhang%2FDocuments%2FGitHub%2Fomni%2Fweb&isDev=true&tsconfigPath=tsconfig.json&basePath=&assetPrefix=&nextConfigOutput=&preferredRegion=&middlewareConfig=e30%3D!\n");

/***/ }),

/***/ "(rsc)/./app/api/mbti/route.ts":
/*!*******************************!*\
  !*** ./app/api/mbti/route.ts ***!
  \*******************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

eval("__webpack_require__.r(__webpack_exports__);\n/* harmony export */ __webpack_require__.d(__webpack_exports__, {\n/* harmony export */   POST: () => (/* binding */ POST)\n/* harmony export */ });\n/* harmony import */ var next_server__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! next/server */ \"(rsc)/./node_modules/next/dist/api/server.js\");\n\nasync function POST(request) {\n    try {\n        const body = await request.json();\n        const { answers, locale } = body;\n        const isZh = locale === \"zh\";\n        const type = \"INTJ\";\n        const facets = isZh ? {\n            EI: {\n                score: 75,\n                label: \"内向\",\n                facets: [\n                    \"接收\",\n                    \"内敛\",\n                    \"亲密\",\n                    \"反思\",\n                    \"安静\"\n                ],\n                image: \"/assets/mbti_intuition_1769151546183.png\"\n            },\n            SN: {\n                score: 60,\n                label: \"直觉\",\n                facets: [\n                    \"抽象\",\n                    \"想象\",\n                    \"概念\",\n                    \"理论\",\n                    \"原创\"\n                ],\n                image: \"/assets/mbti_intuition_1769151546183.png\"\n            },\n            TF: {\n                score: 85,\n                label: \"思考\",\n                facets: [\n                    \"逻辑\",\n                    \"理性\",\n                    \"质疑\",\n                    \"批判\",\n                    \"坚强\"\n                ],\n                image: \"/assets/mbti_thinking_1769151561204.png\"\n            },\n            JP: {\n                score: 55,\n                label: \"判断\",\n                facets: [\n                    \"系统\",\n                    \"计划\",\n                    \"提前启动\",\n                    \"日程化\",\n                    \"条理\"\n                ],\n                image: \"/assets/mbti_thinking_1769151561204.png\"\n            }\n        } : {\n            EI: {\n                score: 75,\n                label: \"Introverted\",\n                facets: [\n                    \"Receiving\",\n                    \"Contained\",\n                    \"Intimate\",\n                    \"Reflective\",\n                    \"Quiet\"\n                ],\n                image: \"/assets/mbti_intuition_1769151546183.png\"\n            },\n            SN: {\n                score: 60,\n                label: \"Intuitive\",\n                facets: [\n                    \"Abstract\",\n                    \"Imaginative\",\n                    \"Conceptual\",\n                    \"Theoretical\",\n                    \"Original\"\n                ],\n                image: \"/assets/mbti_intuition_1769151546183.png\"\n            },\n            TF: {\n                score: 85,\n                label: \"Thinking\",\n                facets: [\n                    \"Logical\",\n                    \"Reasonable\",\n                    \"Questioning\",\n                    \"Critical\",\n                    \"Tough\"\n                ],\n                image: \"/assets/mbti_thinking_1769151561204.png\"\n            },\n            JP: {\n                score: 55,\n                label: \"Judging\",\n                facets: [\n                    \"Systematic\",\n                    \"Planful\",\n                    \"Early-Starting\",\n                    \"Scheduled\",\n                    \"Methodical\"\n                ],\n                image: \"/assets/mbti_thinking_1769151561204.png\"\n            }\n        };\n        const midZones = isZh ? [\n            \"你在'系统性 vs 随意性'维度上显示出中间区域偏好，表明你可以根据压力水平调整你的计划方式。\"\n        ] : [\n            \"You show a mid-zone preference on the 'Systematic vs Casual' facet, suggesting you can adapt your planning style depending on stress levels.\"\n        ];\n        // Simulate delay\n        await new Promise((resolve)=>setTimeout(resolve, 1000));\n        // --- Database Integration ---\n        try {\n            const { getServerSession } = await Promise.all(/*! import() */[__webpack_require__.e(\"vendor-chunks/next\"), __webpack_require__.e(\"vendor-chunks/next-auth\"), __webpack_require__.e(\"vendor-chunks/@babel\"), __webpack_require__.e(\"vendor-chunks/jose\"), __webpack_require__.e(\"vendor-chunks/openid-client\"), __webpack_require__.e(\"vendor-chunks/oauth\"), __webpack_require__.e(\"vendor-chunks/preact\"), __webpack_require__.e(\"vendor-chunks/yallist\"), __webpack_require__.e(\"vendor-chunks/preact-render-to-string\"), __webpack_require__.e(\"vendor-chunks/cookie\"), __webpack_require__.e(\"vendor-chunks/oidc-token-hash\"), __webpack_require__.e(\"vendor-chunks/@panva\")]).then(__webpack_require__.t.bind(__webpack_require__, /*! next-auth */ \"(rsc)/./node_modules/next-auth/index.js\", 23));\n            const { authOptions } = await Promise.all(/*! import() */[__webpack_require__.e(\"vendor-chunks/next\"), __webpack_require__.e(\"vendor-chunks/next-auth\"), __webpack_require__.e(\"vendor-chunks/@babel\"), __webpack_require__.e(\"vendor-chunks/jose\"), __webpack_require__.e(\"vendor-chunks/openid-client\"), __webpack_require__.e(\"vendor-chunks/oauth\"), __webpack_require__.e(\"vendor-chunks/preact\"), __webpack_require__.e(\"vendor-chunks/yallist\"), __webpack_require__.e(\"vendor-chunks/preact-render-to-string\"), __webpack_require__.e(\"vendor-chunks/cookie\"), __webpack_require__.e(\"vendor-chunks/oidc-token-hash\"), __webpack_require__.e(\"vendor-chunks/@panva\"), __webpack_require__.e(\"vendor-chunks/@auth\"), __webpack_require__.e(\"_rsc_app_api_auth_nextauth_route_ts\")]).then(__webpack_require__.bind(__webpack_require__, /*! ../auth/[...nextauth]/route */ \"(rsc)/./app/api/auth/[...nextauth]/route.ts\"));\n            const session = await getServerSession(authOptions);\n            if (session?.user?.id) {\n                const { prisma } = await __webpack_require__.e(/*! import() */ \"_rsc_lib_prisma_ts\").then(__webpack_require__.bind(__webpack_require__, /*! @/lib/prisma */ \"(rsc)/./lib/prisma.ts\"));\n                await prisma.reading.create({\n                    data: {\n                        type: \"MBTI\",\n                        data: {\n                            answers,\n                            facets,\n                            type\n                        },\n                        result: type,\n                        userId: session.user.id\n                    }\n                });\n            }\n        } catch (dbError) {\n            console.error(\"Failed to save MBTI result to DB:\", dbError);\n        }\n        // ---------------------------\n        return next_server__WEBPACK_IMPORTED_MODULE_0__.NextResponse.json({\n            type,\n            facets,\n            midZones,\n            evolution: isZh ? \"自上次评估以来，你的直觉分数提高了 5%。\" : \"Your Intuition score has increased by 5% since last assessment.\"\n        });\n    } catch (error) {\n        return next_server__WEBPACK_IMPORTED_MODULE_0__.NextResponse.json({\n            error: \"Invalid request\"\n        }, {\n            status: 400\n        });\n    }\n}\n//# sourceURL=[module]\n//# sourceMappingURL=data:application/json;charset=utf-8;base64,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QztZQUFFOEIsT0FBTztRQUFrQixHQUFHO1lBQUVFLFFBQVE7UUFBSTtJQUN2RTtBQUNGIiwic291cmNlcyI6WyJ3ZWJwYWNrOi8vb21uaS13ZWIvLi9hcHAvYXBpL21idGkvcm91dGUudHM/NTY5ZSJdLCJzb3VyY2VzQ29udGVudCI6WyJpbXBvcnQgeyBOZXh0UmVzcG9uc2UgfSBmcm9tICduZXh0L3NlcnZlcic7XG5cbmV4cG9ydCBhc3luYyBmdW5jdGlvbiBQT1NUKHJlcXVlc3Q6IFJlcXVlc3QpIHtcbiAgdHJ5IHtcbiAgICBjb25zdCBib2R5ID0gYXdhaXQgcmVxdWVzdC5qc29uKCk7XG4gICAgY29uc3QgeyBhbnN3ZXJzLCBsb2NhbGUgfSA9IGJvZHk7XG4gICAgY29uc3QgaXNaaCA9IGxvY2FsZSA9PT0gJ3poJztcblxuICAgIGNvbnN0IHR5cGUgPSBcIklOVEpcIjtcblxuICAgIGNvbnN0IGZhY2V0cyA9IGlzWmggPyB7XG4gICAgICBFSTogeyBzY29yZTogNzUsIGxhYmVsOiBcIuWGheWQkVwiLCBmYWNldHM6IFtcIuaOpeaUtlwiLCBcIuWGheaVm1wiLCBcIuS6suWvhlwiLCBcIuWPjeaAnVwiLCBcIuWuiemdmVwiXSwgaW1hZ2U6IFwiL2Fzc2V0cy9tYnRpX2ludHVpdGlvbl8xNzY5MTUxNTQ2MTgzLnBuZ1wiIH0sXG4gICAgICBTTjogeyBzY29yZTogNjAsIGxhYmVsOiBcIuebtOiniVwiLCBmYWNldHM6IFtcIuaKveixoVwiLCBcIuaDs+ixoVwiLCBcIuamguW/tVwiLCBcIueQhuiuulwiLCBcIuWOn+WIm1wiXSwgaW1hZ2U6IFwiL2Fzc2V0cy9tYnRpX2ludHVpdGlvbl8xNzY5MTUxNTQ2MTgzLnBuZ1wiIH0sXG4gICAgICBURjogeyBzY29yZTogODUsIGxhYmVsOiBcIuaAneiAg1wiLCBmYWNldHM6IFtcIumAu+i+kVwiLCBcIueQhuaAp1wiLCBcIui0qOeWkVwiLCBcIuaJueWIpFwiLCBcIuWdmuW8ulwiXSwgaW1hZ2U6IFwiL2Fzc2V0cy9tYnRpX3RoaW5raW5nXzE3NjkxNTE1NjEyMDQucG5nXCIgfSxcbiAgICAgIEpQOiB7IHNjb3JlOiA1NSwgbGFiZWw6IFwi5Yik5patXCIsIGZhY2V0czogW1wi57O757ufXCIsIFwi6K6h5YiSXCIsIFwi5o+Q5YmN5ZCv5YqoXCIsIFwi5pel56iL5YyWXCIsIFwi5p2h55CGXCJdLCBpbWFnZTogXCIvYXNzZXRzL21idGlfdGhpbmtpbmdfMTc2OTE1MTU2MTIwNC5wbmdcIiB9XG4gICAgfSA6IHtcbiAgICAgIEVJOiB7IHNjb3JlOiA3NSwgbGFiZWw6IFwiSW50cm92ZXJ0ZWRcIiwgZmFjZXRzOiBbXCJSZWNlaXZpbmdcIiwgXCJDb250YWluZWRcIiwgXCJJbnRpbWF0ZVwiLCBcIlJlZmxlY3RpdmVcIiwgXCJRdWlldFwiXSwgaW1hZ2U6IFwiL2Fzc2V0cy9tYnRpX2ludHVpdGlvbl8xNzY5MTUxNTQ2MTgzLnBuZ1wiIH0sXG4gICAgICBTTjogeyBzY29yZTogNjAsIGxhYmVsOiBcIkludHVpdGl2ZVwiLCBmYWNldHM6IFtcIkFic3RyYWN0XCIsIFwiSW1hZ2luYXRpdmVcIiwgXCJDb25jZXB0dWFsXCIsIFwiVGhlb3JldGljYWxcIiwgXCJPcmlnaW5hbFwiXSwgaW1hZ2U6IFwiL2Fzc2V0cy9tYnRpX2ludHVpdGlvbl8xNzY5MTUxNTQ2MTgzLnBuZ1wiIH0sXG4gICAgICBURjogeyBzY29yZTogODUsIGxhYmVsOiBcIlRoaW5raW5nXCIsIGZhY2V0czogW1wiTG9naWNhbFwiLCBcIlJlYXNvbmFibGVcIiwgXCJRdWVzdGlvbmluZ1wiLCBcIkNyaXRpY2FsXCIsIFwiVG91Z2hcIl0sIGltYWdlOiBcIi9hc3NldHMvbWJ0aV90aGlua2luZ18xNzY5MTUxNTYxMjA0LnBuZ1wiIH0sXG4gICAgICBKUDogeyBzY29yZTogNTUsIGxhYmVsOiBcIkp1ZGdpbmdcIiwgZmFjZXRzOiBbXCJTeXN0ZW1hdGljXCIsIFwiUGxhbmZ1bFwiLCBcIkVhcmx5LVN0YXJ0aW5nXCIsIFwiU2NoZWR1bGVkXCIsIFwiTWV0aG9kaWNhbFwiXSwgaW1hZ2U6IFwiL2Fzc2V0cy9tYnRpX3RoaW5raW5nXzE3NjkxNTE1NjEyMDQucG5nXCIgfVxuICAgIH07XG5cbiAgICBjb25zdCBtaWRab25lcyA9IGlzWmhcbiAgICAgID8gW1wi5L2g5ZyoJ+ezu+e7n+aApyB2cyDpmo/mhI/mgKcn57u05bqm5LiK5pi+56S65Ye65Lit6Ze05Yy65Z+f5YGP5aW977yM6KGo5piO5L2g5Y+v5Lul5qC55o2u5Y6L5Yqb5rC05bmz6LCD5pW05L2g55qE6K6h5YiS5pa55byP44CCXCJdXG4gICAgICA6IFtcIllvdSBzaG93IGEgbWlkLXpvbmUgcHJlZmVyZW5jZSBvbiB0aGUgJ1N5c3RlbWF0aWMgdnMgQ2FzdWFsJyBmYWNldCwgc3VnZ2VzdGluZyB5b3UgY2FuIGFkYXB0IHlvdXIgcGxhbm5pbmcgc3R5bGUgZGVwZW5kaW5nIG9uIHN0cmVzcyBsZXZlbHMuXCJdO1xuXG4gICAgLy8gU2ltdWxhdGUgZGVsYXlcbiAgICBhd2FpdCBuZXcgUHJvbWlzZShyZXNvbHZlID0+IHNldFRpbWVvdXQocmVzb2x2ZSwgMTAwMCkpO1xuXG4gICAgLy8gLS0tIERhdGFiYXNlIEludGVncmF0aW9uIC0tLVxuICAgIHRyeSB7XG4gICAgICBjb25zdCB7IGdldFNlcnZlclNlc3Npb24gfSA9IGF3YWl0IGltcG9ydChcIm5leHQtYXV0aFwiKTtcbiAgICAgIGNvbnN0IHsgYXV0aE9wdGlvbnMgfSA9IGF3YWl0IGltcG9ydChcIi4uL2F1dGgvWy4uLm5leHRhdXRoXS9yb3V0ZVwiKTtcbiAgICAgIGNvbnN0IHNlc3Npb24gPSBhd2FpdCBnZXRTZXJ2ZXJTZXNzaW9uKGF1dGhPcHRpb25zKTtcblxuICAgICAgaWYgKHNlc3Npb24/LnVzZXI/LmlkKSB7XG4gICAgICAgIGNvbnN0IHsgcHJpc21hIH0gPSBhd2FpdCBpbXBvcnQoXCJAL2xpYi9wcmlzbWFcIik7XG4gICAgICAgIGF3YWl0IHByaXNtYS5yZWFkaW5nLmNyZWF0ZSh7XG4gICAgICAgICAgZGF0YToge1xuICAgICAgICAgICAgdHlwZTogXCJNQlRJXCIsXG4gICAgICAgICAgICBkYXRhOiB7IGFuc3dlcnMsIGZhY2V0cywgdHlwZSB9LFxuICAgICAgICAgICAgcmVzdWx0OiB0eXBlLFxuICAgICAgICAgICAgdXNlcklkOiBzZXNzaW9uLnVzZXIuaWRcbiAgICAgICAgICB9XG4gICAgICAgIH0pO1xuICAgICAgfVxuICAgIH0gY2F0Y2ggKGRiRXJyb3IpIHtcbiAgICAgIGNvbnNvbGUuZXJyb3IoXCJGYWlsZWQgdG8gc2F2ZSBNQlRJIHJlc3VsdCB0byBEQjpcIiwgZGJFcnJvcik7XG4gICAgfVxuICAgIC8vIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLVxuXG4gICAgcmV0dXJuIE5leHRSZXNwb25zZS5qc29uKHtcbiAgICAgIHR5cGUsXG4gICAgICBmYWNldHMsXG4gICAgICBtaWRab25lcyxcbiAgICAgIGV2b2x1dGlvbjogaXNaaCA/IFwi6Ieq5LiK5qyh6K+E5Lyw5Lul5p2l77yM5L2g55qE55u06KeJ5YiG5pWw5o+Q6auY5LqGIDUl44CCXCIgOiBcIllvdXIgSW50dWl0aW9uIHNjb3JlIGhhcyBpbmNyZWFzZWQgYnkgNSUgc2luY2UgbGFzdCBhc3Nlc3NtZW50LlwiXG4gICAgfSk7XG5cbiAgfSBjYXRjaCAoZXJyb3IpIHtcbiAgICByZXR1cm4gTmV4dFJlc3BvbnNlLmpzb24oeyBlcnJvcjogXCJJbnZhbGlkIHJlcXVlc3RcIiB9LCB7IHN0YXR1czogNDAwIH0pO1xuICB9XG59XG4iXSwibmFtZXMiOlsiTmV4dFJlc3BvbnNlIiwiUE9TVCIsInJlcXVlc3QiLCJib2R5IiwianNvbiIsImFuc3dlcnMiLCJsb2NhbGUiLCJpc1poIiwidHlwZSIsImZhY2V0cyIsIkVJIiwic2NvcmUiLCJsYWJlbCIsImltYWdlIiwiU04iLCJURiIsIkpQIiwibWlkWm9uZXMiLCJQcm9taXNlIiwicmVzb2x2ZSIsInNldFRpbWVvdXQiLCJnZXRTZXJ2ZXJTZXNzaW9uIiwiYXV0aE9wdGlvbnMiLCJzZXNzaW9uIiwidXNlciIsImlkIiwicHJpc21hIiwicmVhZGluZyIsImNyZWF0ZSIsImRhdGEiLCJyZXN1bHQiLCJ1c2VySWQiLCJkYkVycm9yIiwiY29uc29sZSIsImVycm9yIiwiZXZvbHV0aW9uIiwic3RhdHVzIl0sInNvdXJjZVJvb3QiOiIifQ==\n//# sourceURL=webpack-internal:///(rsc)/./app/api/mbti/route.ts\n");

/***/ })

};
;

// load runtime
var __webpack_require__ = require("../../../webpack-runtime.js");
__webpack_require__.C(exports);
var __webpack_exec__ = (moduleId) => (__webpack_require__(__webpack_require__.s = moduleId))
var __webpack_exports__ = __webpack_require__.X(0, ["vendor-chunks/next"], () => (__webpack_exec__("(rsc)/./node_modules/next/dist/build/webpack/loaders/next-app-loader.js?name=app%2Fapi%2Fmbti%2Froute&page=%2Fapi%2Fmbti%2Froute&appPaths=&pagePath=private-next-app-dir%2Fapi%2Fmbti%2Froute.ts&appDir=%2FUsers%2Fxiaobozhang%2FDocuments%2FGitHub%2Fomni%2Fweb%2Fapp&pageExtensions=tsx&pageExtensions=ts&pageExtensions=jsx&pageExtensions=js&rootDir=%2FUsers%2Fxiaobozhang%2FDocuments%2FGitHub%2Fomni%2Fweb&isDev=true&tsconfigPath=tsconfig.json&basePath=&assetPrefix=&nextConfigOutput=&preferredRegion=&middlewareConfig=e30%3D!")));
module.exports = __webpack_exports__;

})();