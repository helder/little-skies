// The release's numbers into helder.json before a store build:
//
//   node .github/scripts/version.mjs <ref> <build>
//
// A version tag (v1.2.0) is "version": "1.2.0"; another ref (a branch: a
// dry run) keeps helder.json's. <build> (the workflow's run number plus 100,
// past the first bundle uploaded to Play by hand) is "build": Android's versionCode and iOS's CFBundleVersion,
// which both stores want higher than the last upload's.
import fs from 'node:fs';

const [ref, build] = process.argv.slice(2);
const json = JSON.parse(fs.readFileSync('helder.json', 'utf8'));
if (/^v\d+(\.\d+){0,2}$/.test(ref ?? '')) json.version = ref.slice(1);
const n = Number(build);
if (!Number.isInteger(n) || n < 1) throw new Error(`version.mjs: the build number ${build} is not a whole number from 1`);
json.build = n;
fs.writeFileSync('helder.json', JSON.stringify(json, null, 2) + '\n');
console.log(`version ${json.version}, build ${json.build}`);
