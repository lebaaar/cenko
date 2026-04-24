# Firebase Functions

To deploy the Firebase functions:
```bash
cd functions
npm install
npm run build
cd ..
firebase deploy --only functions
```

To run functions locally:
```bash
cd functions
npm install
npm run build
cd ..
firebase emulators:start --only functions
```
