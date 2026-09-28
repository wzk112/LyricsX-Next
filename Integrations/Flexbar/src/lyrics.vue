<template>
  <v-container>
    <v-select v-model="secondary" label="辅助行" :items="[{title:'译文优先',value:'translation'},{title:'下一句',value:'next'},{title:'关闭',value:'off'}]" />
    <v-select v-model="alignment" label="文字对齐" :items="[{title:'居中',value:'center'},{title:'靠左',value:'left'}]" />
    <v-select v-if="immersive" v-model="orientation" label="画面方向" :items="[{title:'跟随设备',value:'auto'},{title:'默认方向',value:'normal'},{title:'旋转 180°',value:'flipped'}]" />
    <v-select v-model="fps" label="动画流畅度" :items="[{title:'超流畅（60 fps 目标）',value:60},{title:'流畅（30 fps）',value:30},{title:'均衡（20 fps）',value:20},{title:'省电（15 fps）',value:15}]" />
    <v-switch v-if="immersive" v-model="diffUpdate" label="尝试部分刷新（可能撕裂）" />
    <p>整屏默认跟随设备翻转并居中。辅助行关闭时使用大号单行。点击可分页阅读；末页后返回自动显示。</p>
  </v-container>
</template>
<script>
export default {
  props: { modelValue: { type: Object, required: true } }, emits: ['update:modelValue'],
  computed: {
    immersive() { return this.modelValue.cid?.endsWith('.immersive') === true; },
    secondary: { get() { return this.modelValue.data?.secondary ?? 'translation'; }, set(value) { this.write('secondary', value); } },
    alignment: { get() { return this.modelValue.data?.alignment ?? (this.immersive ? 'center' : 'left'); }, set(value) { this.write('alignment', value); } },
    orientation: { get() { return this.modelValue.data?.orientation ?? 'auto'; }, set(value) { this.write('orientation', value); } },
    fps: { get() { return this.modelValue.data?.fps ?? 30; }, set(value) { this.write('fps', value); } },
    diffUpdate: { get() { return this.modelValue.data?.diffUpdate === true; }, set(value) { this.write('diffUpdate', value); } }
  },
  methods: { write(key, value) { this.$emit('update:modelValue', { ...this.modelValue, data: { ...this.modelValue.data, [key]: value } }); } }
};
</script>
